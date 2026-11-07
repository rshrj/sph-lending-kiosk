"""Vision: what *kind* of item is on the tray (QR labels say which unit).

A YOLO detector (Ultralytics). Its class names, lower-cased with spaces as underscores, are
matched against `items.vision_label` ("cell phone" → `cell_phone`). Off unless KIOSK_VISION
names a model, so the base install doesn't need torch:

    KIOSK_VISION=yolo26n.pt           COCO-pretrained (80 everyday classes), downloaded on first use
    KIOSK_VISION=runs/.../best.pt     a model fine-tuned on your own basket
    KIOSK_VISION_CONF=0.4             minimum confidence (default 0.4)

Needs `pip install -r requirements-vision.txt`.
"""

import logging
import os
import threading
from dataclasses import dataclass

import numpy as np

log = logging.getLogger(__name__)


@dataclass
class Detection:
    label: str                              # == items.vision_label
    confidence: float                       # 0..1
    bbox: tuple[int, int, int, int]         # x, y, w, h in image pixels


MODEL = os.environ.get("KIOSK_VISION", "off").strip() or "off"
CONF = float(os.environ.get("KIOSK_VISION_CONF", "0.4"))
ENABLED = False

_model = None
_lock = threading.Lock()  # one predict at a time; FastAPI runs sync endpoints on a thread pool


def label_for(class_name: str) -> str:
    return class_name.strip().lower().replace(" ", "_")


def load() -> None:
    """Load the model named by KIOSK_VISION (at startup, so the first scan isn't slow)."""
    global _model, ENABLED
    if MODEL == "off" or _model is not None:
        return
    try:
        from ultralytics import YOLO
    except ImportError:
        log.warning("KIOSK_VISION=%s but ultralytics isn't installed (requirements-vision.txt); vision off", MODEL)
        return
    try:
        model = YOLO(MODEL)
        model.predict(np.zeros((480, 640, 3), np.uint8), verbose=False)  # warm-up
    except Exception:
        log.exception("could not load vision model %s; vision off", MODEL)
        return
    _model, ENABLED = model, True
    log.info("vision model %s: %d classes, conf >= %.2f", MODEL, len(model.names), CONF)


def detect(image: np.ndarray) -> list[Detection]:
    if _model is None:
        return []
    with _lock:
        res = _model.predict(image, conf=CONF, verbose=False)[0]
    out = []
    for (x1, y1, x2, y2), c, p in zip(res.boxes.xyxy.tolist(), res.boxes.cls.tolist(), res.boxes.conf.tolist()):
        out.append(Detection(label_for(res.names[int(c)]), float(p),
                             (round(x1), round(y1), round(x2 - x1), round(y2 - y1))))
    return out
