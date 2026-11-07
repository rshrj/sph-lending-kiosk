"""Vision: what *kind* of item is on the tray (QR labels say which unit).

A YOLO detector (Ultralytics). Its class names, lower-cased with spaces as underscores, are
matched against `items.vision_label` ("cell phone" → `cell_phone`). Off unless KIOSK_VISION
names a model, so the base install doesn't need torch:

    KIOSK_VISION=yolo26n.pt           COCO-pretrained (80 everyday classes), downloaded on first use
    KIOSK_VISION=data/models/current.pt   a model fine-tuned on your basket (tools/train.py)
    KIOSK_VISION_CONF=0.4             minimum confidence (default 0.4)

A model given as a path (it contains a "/") is watched: when tools/train.py replaces the file the
new model is loaded on the next scan, and until the first one exists vision just stays off.

Needs `pip install -r requirements-vision.txt`.
"""

import logging
import os
import threading
import time
from dataclasses import dataclass
from pathlib import Path

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
_watch = Path(MODEL) if "/" in MODEL else None   # a local file to reload when it changes
_mtime = 0.0
_checked = 0.0


def label_for(class_name: str) -> str:
    return class_name.strip().lower().replace(" ", "_")


def load() -> None:
    """Load the model named by KIOSK_VISION (at startup, so the first scan isn't slow)."""
    global _model, ENABLED, _mtime
    if MODEL == "off":
        return
    if _watch is not None:
        if not _watch.is_file():
            log.info("vision model %s doesn't exist yet; it is loaded once tools/train.py writes it", _watch)
            return
        _mtime = _watch.stat().st_mtime   # even if loading fails: retry only when the file changes again
    try:
        from ultralytics import YOLO
    except ImportError:
        log.warning("KIOSK_VISION=%s but ultralytics isn't installed (requirements-vision.txt); vision off", MODEL)
        return
    try:
        model = YOLO(MODEL)
        model.predict(np.zeros((480, 640, 3), np.uint8), verbose=False)  # warm-up
    except Exception:
        log.exception("could not load vision model %s; keeping the previous one", MODEL)
        return
    with _lock:
        _model, ENABLED = model, True
    log.info("vision model %s: %d classes (%s), conf >= %.2f", MODEL, len(model.names),
             ", ".join(label_for(n) for n in model.names.values()), CONF)


def _maybe_reload() -> None:
    """Pick up a retrained model (checked at most every 2 s)."""
    global _checked
    if _watch is None or time.monotonic() - _checked < 2:
        return
    _checked = time.monotonic()
    try:
        changed = _watch.stat().st_mtime != _mtime
    except FileNotFoundError:
        return
    if changed:
        load()


def info() -> dict:
    """For the staff screens: which model, which kinds it knows."""
    m = _model
    return {"model": None if MODEL == "off" else MODEL, "enabled": ENABLED,
            "labels": sorted(label_for(n) for n in m.names.values()) if m else [],
            "updated": _mtime or None}


def detect(image: np.ndarray) -> list[Detection]:
    _maybe_reload()
    if _model is None:
        return []
    with _lock:
        res = _model.predict(image, conf=CONF, verbose=False)[0]
    out = []
    for (x1, y1, x2, y2), c, p in zip(res.boxes.xyxy.tolist(), res.boxes.cls.tolist(), res.boxes.conf.tolist()):
        out.append(Detection(label_for(res.names[int(c)]), float(p),
                             (round(x1), round(y1), round(x2 - x1), round(y2 - y1))))
    return out
