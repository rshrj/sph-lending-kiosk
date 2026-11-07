"""Teach mode: collect training photos for the vision model, labelled automatically.

The camera looks down on a fixed tray, so an item is "whatever differs from the empty tray".
Staff photograph the empty tray once, pick a kind, then put one item on the tray and keep
moving or turning it. Each time the picture is still (hand out of the way) and the item has
moved since the last photo, the frame is saved with the box around the difference. That is
a ready-made YOLO training sample; tools/train.py turns the folder into a model.

Dataset layout (KIOSK_DATASET, default backend/data/dataset/):
    <vision_label>/<stamp>.jpg + .json   {"label", "bbox": [x, y, w, h], "size": [w, h]}
    _empty/<stamp>.jpg                    empty tray: negative samples (nothing to find)
"""

import json
import os
import re
import threading
import time
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np

from . import db

DATASET_DIR = Path(os.environ.get("KIOSK_DATASET", db.PKG.parent / "data" / "dataset"))
EMPTY = "_empty"
SAVE_WIDTH = 1280          # stored image width (YOLO trains at 640; keeps the dataset small)
WORK_WIDTH = 480           # resolution the differencing runs at
DIFF_THRESHOLD = 28        # per-pixel colour difference that counts as "changed" (0..255)
MIN_AREA = 0.002           # ignore blobs smaller than this fraction of the frame
MAX_AREA = 0.6             # bigger than this: the light or the camera changed, not an item
MOTION = 0.004             # fraction of pixels changed since the previous frame = still moving
SAME_IOU = 0.85            # box overlaps the last saved one this much (and looks alike) = not moved

_LABEL = re.compile(r"^[a-z0-9_]{1,64}$")


def valid_label(label: str) -> bool:
    return bool(_LABEL.match(label)) and label != EMPTY


@dataclass
class Result:
    status: str                                   # saved | moving | empty | too_big | same | no_background
    message: str
    bbox: tuple[int, int, int, int] | None = None  # in the input image's pixels
    count: int = 0                                 # samples of this label after the call


def _work(img: np.ndarray) -> np.ndarray:
    """Small, blurred Lab copy for differencing (Lab: lighting shifts mostly hit one channel)."""
    h, w = img.shape[:2]
    small = cv2.resize(img, (WORK_WIDTH, round(h * WORK_WIDTH / w)), interpolation=cv2.INTER_AREA)
    return cv2.cvtColor(cv2.GaussianBlur(small, (5, 5), 0), cv2.COLOR_BGR2LAB).astype(np.int16)


def _changed(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Mask of pixels that differ, after removing a global shift (auto-exposure, white balance)."""
    d = a - b
    d -= np.median(d.reshape(-1, 3), axis=0).astype(np.int16)
    return (np.abs(d).max(axis=2) > DIFF_THRESHOLD).astype(np.uint8)


def _iou(a, b) -> float:
    ax2, ay2, bx2, by2 = a[0] + a[2], a[1] + a[3], b[0] + b[2], b[1] + b[3]
    iw = max(0, min(ax2, bx2) - max(a[0], b[0]))
    ih = max(0, min(ay2, by2) - max(a[1], b[1]))
    inter = iw * ih
    union = a[2] * a[3] + b[2] * b[3] - inter
    return inter / union if union else 0.0


def find_object(background: np.ndarray, frame: np.ndarray) -> tuple[tuple[int, int, int, int] | None, float]:
    """Box (in work pixels) around everything that isn't the empty tray, and its area fraction."""
    mask = _changed(frame, background)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((11, 11), np.uint8))
    n, _, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    total = mask.shape[0] * mask.shape[1]
    blobs = [s for s in stats[1:n] if s[cv2.CC_STAT_AREA] >= MIN_AREA * total]
    if not blobs:
        return None, 0.0
    x1 = min(s[0] for s in blobs); y1 = min(s[1] for s in blobs)
    x2 = max(s[0] + s[2] for s in blobs); y2 = max(s[1] + s[3] for s in blobs)
    return (int(x1), int(y1), int(x2 - x1), int(y2 - y1)), (x2 - x1) * (y2 - y1) / total


class Teacher:
    def __init__(self, root: Path | None = None):
        self.root = root or DATASET_DIR
        self._lock = threading.Lock()
        self._background: np.ndarray | None = None
        self._prev: np.ndarray | None = None
        self._last: dict[str, tuple] = {}         # label -> (bbox in work px, work frame) of the last save
        self._undo: list[Path] = []               # saved files, newest last

    @property
    def has_background(self) -> bool:
        return self._background is not None

    def counts(self) -> dict[str, int]:
        if not self.root.is_dir():
            return {}
        return {d.name: sum(1 for _ in d.glob("*.jpg")) for d in sorted(self.root.iterdir()) if d.is_dir()}

    def _save(self, folder: str, img: np.ndarray, meta: dict | None) -> Path:
        h, w = img.shape[:2]
        scale = min(1.0, SAVE_WIDTH / w)
        if scale < 1:
            img = cv2.resize(img, (round(w * scale), round(h * scale)), interpolation=cv2.INTER_AREA)
        d = self.root / folder
        d.mkdir(parents=True, exist_ok=True)
        stem = time.strftime("%Y%m%d-%H%M%S") + f"-{time.time_ns() % 1_000_000_000:09d}"
        path = d / f"{stem}.jpg"
        cv2.imwrite(str(path), img, [cv2.IMWRITE_JPEG_QUALITY, 90])
        if meta is not None:
            meta = {**meta, "bbox": [round(v * scale) for v in meta["bbox"]], "size": [img.shape[1], img.shape[0]]}
            path.with_suffix(".json").write_text(json.dumps(meta) + "\n")
        self._undo.append(path)
        return path

    def set_background(self, frames: list[np.ndarray]) -> None:
        """Empty tray: average a few frames as the reference, keep one as a negative sample."""
        with self._lock:
            self._background = np.mean([_work(f) for f in frames], axis=0).astype(np.int16)
            self._prev = None
            self._last.clear()
            self._save(EMPTY, frames[-1], None)

    def capture(self, label: str, img: np.ndarray) -> Result:
        with self._lock:
            count = self.counts().get(label, 0)
            if self._background is None:
                return Result("no_background", "Photograph the empty tray first.", count=count)
            work = _work(img)
            prev, self._prev = self._prev, work
            if prev is None or prev.shape != work.shape or _changed(work, prev).mean() > MOTION:
                return Result("moving", "Hold still…", count=count)

            box, area = find_object(self._background, work)
            sx = img.shape[1] / work.shape[1]
            full = tuple(round(v * sx) for v in box) if box else None
            if box is None:
                return Result("empty", "Put the item on the tray.", count=count)
            if area > MAX_AREA:
                return Result("too_big", "Most of the picture changed. Clear the tray and photograph it empty again.",
                              full, count)
            last = self._last.get(label)
            if last and _iou(box, last[0]) > SAME_IOU and _changed(work, last[1]).mean() < MOTION:
                return Result("same", "Got this one. Move or turn the item.", full, count)

            self._save(label, img, {"label": label, "bbox": list(full)})
            self._last[label] = (box, work)
            return Result("saved", f"Saved photo {count + 1}.", full, count + 1)

    def undo(self) -> str | None:
        """Delete the newest saved photo (and its box); returns its folder name."""
        with self._lock:
            while self._undo:
                path = self._undo.pop()
                if path.exists():
                    path.unlink()
                    path.with_suffix(".json").unlink(missing_ok=True)
                    self._last.pop(path.parent.name, None)
                    return path.parent.name
            return None
