"""Overhead tray camera (USB UVC webcam).

A background thread keeps grabbing frames so the buffer is never stale and auto-exposure
stays settled; a frame is only decoded (retrieve) when someone asks for one.
"""

import logging
import os
import sys
import threading
import time

import cv2
import numpy as np

log = logging.getLogger(__name__)


def _default_device() -> str:
    # On the Pi, keep trying /dev/video0 even if the webcam is plugged in later; elsewhere (Mac
    # dev) the camera stays off unless KIOSK_CAMERA asks for one.
    return "/dev/video0" if sys.platform.startswith("linux") or os.path.exists("/dev/video0") else "off"


class Camera:
    def __init__(self, device: str | None = None, width: int = 1920, height: int = 1080):
        self.device = device or os.environ.get("KIOSK_CAMERA") or _default_device()
        self.width, self.height = width, height
        self._cap: cv2.VideoCapture | None = None
        self._lock = threading.Lock()
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    @property
    def enabled(self) -> bool:
        return self.device != "off"

    @property
    def ready(self) -> bool:
        return self._cap is not None

    def start(self) -> None:
        if not self.enabled:
            log.info("camera disabled (KIOSK_CAMERA=off)")
            return
        self._thread = threading.Thread(target=self._run, name="camera", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=2)
        with self._lock:
            if self._cap:
                self._cap.release()
                self._cap = None

    def _open(self) -> cv2.VideoCapture | None:
        src = int(self.device) if self.device.isdigit() else self.device
        if isinstance(src, str) and not os.path.exists(src):
            return None  # unplugged: don't let OpenCV log a warning every retry
        cap = cv2.VideoCapture(src, cv2.CAP_V4L2) if isinstance(src, str) else cv2.VideoCapture(src)
        if not cap.isOpened():
            return None
        cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))  # YUYV is only 5 fps at 1080p
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        return cap

    def _run(self) -> None:
        warned = False
        while not self._stop.is_set():
            if self._cap is None:
                cap = self._open()
                if cap is None:
                    if not warned:
                        log.warning("camera %s not available, retrying every 3 s", self.device)
                        warned = True
                    self._stop.wait(3)
                    continue
                warned = False
                with self._lock:
                    self._cap = cap
                log.info("camera %s opened at %dx%d", self.device,
                         int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)), int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)))
            with self._lock:
                ok = self._cap.grab()
            if not ok:
                log.warning("camera grab failed, reopening")
                with self._lock:
                    self._cap.release()
                    self._cap = None
                self._stop.wait(1)
            else:
                time.sleep(0.005)  # let frame() take the lock between grabs

    def frame(self) -> np.ndarray | None:
        """Latest frame as BGR, or None if the camera isn't running."""
        with self._lock:
            if self._cap is None:
                return None
            ok, img = self._cap.retrieve()
        return img if ok else None
