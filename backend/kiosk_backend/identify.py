"""What's on the tray? QR labels (exact unit) + vision model (kind of item)."""

import logging
import re
import time

import cv2
import numpy as np

from . import inventory, vision

log = logging.getLogger(__name__)

try:
    # zxing-cpp is far more robust than OpenCV's QR reader on small, rotated, low-contrast
    # codes as seen by an overhead webcam (decodes ~2.5 px/module at any angle; OpenCV
    # needs ~5 px/module and still misses rotated codes).
    import zxingcpp
except ImportError:  # pragma: no cover - exercised only when the wheel is missing
    zxingcpp = None
    log.warning("zxing-cpp not installed, falling back to OpenCV's QR decoder")

_cv_qr = cv2.QRCodeDetectorAruco() if hasattr(cv2, "QRCodeDetectorAruco") else cv2.QRCodeDetector()

# An asset tag inside a QR payload: "DAIM-001", "daim-001 ", "https://…/item/DAIM-001", …
_TAG = re.compile(r"\b([A-Za-z]{2,10})-(\d{1,6})\b")


def normalize_code(text: str) -> str:
    """The asset tag a QR payload names (upper case), or the trimmed payload if it has none."""
    m = _TAG.search(text)
    return f"{m.group(1).upper()}-{m.group(2)}" if m else text.strip()


def decoder_name() -> str:
    return "zxing-cpp" if zxingcpp else "opencv"


def decode_qr(image: np.ndarray) -> list[tuple[str, tuple[int, int, int, int]]]:
    """All readable QR codes in the image as (raw text, bbox x, y, w, h)."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY) if image.ndim == 3 else image
    if zxingcpp:
        out = []
        for r in zxingcpp.read_barcodes(gray, formats=zxingcpp.BarcodeFormat.QRCode):
            if not r.valid or not r.text:
                continue
            p = r.position
            quad = np.array([[c.x, c.y] for c in (p.top_left, p.top_right, p.bottom_right, p.bottom_left)], np.int32)
            out.append((r.text, tuple(int(v) for v in cv2.boundingRect(quad))))
        return out
    ok, texts, points, _ = _cv_qr.detectAndDecodeMulti(gray)
    if not ok:
        return []
    return [(t, tuple(int(v) for v in cv2.boundingRect(q.astype(np.int32)))) for t, q in zip(texts, points) if t]


_last_seen: tuple[str, ...] | None = None


def _log_change(detections: list[dict], ms: float) -> None:
    """Log what's on the tray when it changes (identify runs about once a second)."""
    global _last_seen
    seen = tuple(sorted(
        (d["code"] if d["items"] else f"foreign QR {d['code'][:24]!r}") if d["method"] == "qr"
        else f"vision:{d['label']}" for d in detections))
    if seen != _last_seen:
        log.info("tray: %s (%.0f ms)", ", ".join(seen) or "empty", ms)
        _last_seen = seen


def identify(conn, image: np.ndarray) -> dict:
    t0 = time.perf_counter()
    detections, seen_codes = [], set()

    for text, bbox in decode_qr(image):
        code = normalize_code(text)
        if code in seen_codes:
            continue
        seen_codes.add(code)
        item = inventory.find_by_tag(conn, code)
        detections.append({
            "method": "qr", "code": code, "confidence": 1.0, "bbox": bbox,
            "items": [item] if item else [],  # empty = a QR code that isn't one of ours
        })

    for d in vision.detect(image):
        units = inventory.find_by_vision_label(conn, d.label)  # every unit of that kind
        if not units:
            continue  # a kind we don't lend (people, laptops, ...): not worth reporting
        detections.append({
            "method": "vision", "label": d.label, "confidence": round(d.confidence, 3), "bbox": d.bbox,
            "items": units,
        })

    _log_change(detections, (time.perf_counter() - t0) * 1000)
    h, w = image.shape[:2]
    return {"image_size": [w, h], "vision_enabled": vision.ENABLED, "qr_decoder": decoder_name(),
            "detections": detections}
