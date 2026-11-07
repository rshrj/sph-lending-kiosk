"""Vision model hook — STUB.

The plan: a YOLO nano model fine-tuned on the demo basket, emitting one class per kind of
item. Each class name must match `items.vision_label` in the database. Replace `detect()`;
nothing else in the backend needs to change.
"""

from dataclasses import dataclass

import numpy as np


@dataclass
class Detection:
    label: str                              # == items.vision_label
    confidence: float                       # 0..1
    bbox: tuple[int, int, int, int]         # x, y, w, h in image pixels


ENABLED = False


def detect(image: np.ndarray) -> list[Detection]:
    return []
