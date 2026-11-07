"""Quick vision smoke test: live YOLO on the tray camera, viewable in a browser.

Grabs frames from the running backend (GET /camera/frame.jpg), so it doesn't fight the
backend for /dev/video0. Serves the annotated stream as MJPEG on http://<pi>:8001/ and prints
detections to stdout.

    # COCO-pretrained YOLO26n (80 everyday classes: scissors, cell phone, mouse, ...)
    python vision_live.py

    # Open-vocabulary YOLOE-26n: name what to look for, no training needed
    python vision_live.py --model yoloe-26n-seg.pt --prompts "multimeter,arduino board,breadboard"
"""

import argparse
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import cv2
import numpy as np
from ultralytics import YOLO

ap = argparse.ArgumentParser()
ap.add_argument("--model", default="yolo26n.pt")
ap.add_argument("--prompts", help="comma-separated class names (YOLOE models only)")
ap.add_argument("--conf", type=float, default=0.25)
ap.add_argument("--imgsz", type=int, default=640)
ap.add_argument("--source", default="http://127.0.0.1:8000/camera/frame.jpg?width=1280")
ap.add_argument("--port", type=int, default=8001)
args = ap.parse_args()

model = YOLO(args.model)
if args.prompts:
    names = [p.strip() for p in args.prompts.split(",") if p.strip()]
    model.set_classes(names, model.get_text_pe(names))
print(f"model {args.model}, {len(model.names)} classes", flush=True)

latest_jpeg: bytes | None = None
cond = threading.Condition()


def grab() -> np.ndarray | None:
    try:
        with urllib.request.urlopen(args.source, timeout=5) as r:
            return cv2.imdecode(np.frombuffer(r.read(), np.uint8), cv2.IMREAD_COLOR)
    except Exception as e:  # backend restarting, camera unplugged, ...
        print("frame fetch failed:", e, flush=True)
        time.sleep(1)
        return None


def loop() -> None:
    global latest_jpeg
    last_seen = None
    ema = None
    while True:
        img = grab()
        if img is None:
            continue
        t0 = time.perf_counter()
        res = model.predict(img, imgsz=args.imgsz, conf=args.conf, verbose=False)[0]
        ms = (time.perf_counter() - t0) * 1000
        ema = ms if ema is None else 0.8 * ema + 0.2 * ms
        out = res.plot()
        cv2.putText(out, f"{args.model}  infer {ema:.0f} ms", (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 255), 2)
        seen = sorted(f"{res.names[int(c)]} {float(p):.2f}" for c, p in zip(res.boxes.cls, res.boxes.conf))
        labels = [s.rsplit(" ", 1)[0] for s in seen]
        if labels != last_seen:
            print(f"[{ms:5.0f} ms] {', '.join(seen) or '(nothing)'}", flush=True)
            last_seen = labels
        ok, buf = cv2.imencode(".jpg", out, [cv2.IMWRITE_JPEG_QUALITY, 75])
        if ok:
            with cond:
                latest_jpeg = buf.tobytes()
                cond.notify_all()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        if self.path == "/snapshot.jpg":
            with cond:
                cond.wait_for(lambda: latest_jpeg is not None)
                data = latest_jpeg
            self.send_response(200)
            self.send_header("Content-Type", "image/jpeg")
            self.end_headers()
            self.wfile.write(data)
            return
        self.send_response(200)
        self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=f")
        self.end_headers()
        try:
            while True:
                with cond:
                    cond.wait()
                    data = latest_jpeg
                self.wfile.write(b"--f\r\nContent-Type: image/jpeg\r\n\r\n" + data + b"\r\n")
        except (BrokenPipeError, ConnectionResetError):
            pass


threading.Thread(target=loop, daemon=True).start()
print(f"live view: http://0.0.0.0:{args.port}/", flush=True)
ThreadingHTTPServer(("0.0.0.0", args.port), Handler).serve_forever()
