"""Print QR asset labels for every item: python -m kiosk_backend.labels [out.png]"""

import sys

import cv2
import numpy as np

from . import db

CELL, QR, COLS = 600, 440, 3


def main(out: str = "labels.png") -> None:
    conn = db.connect()
    db.init(conn)
    items = conn.execute("SELECT asset_tag, name FROM items ORDER BY asset_tag").fetchall()
    enc = cv2.QRCodeEncoder.create()
    rows = (len(items) + COLS - 1) // COLS
    sheet = np.full((rows * CELL, COLS * CELL, 3), 255, np.uint8)
    for i, it in enumerate(items):
        qr = cv2.resize(enc.encode(it["asset_tag"]), (QR, QR), interpolation=cv2.INTER_NEAREST)
        x, y = (i % COLS) * CELL, (i // COLS) * CELL
        sheet[y + 30:y + 30 + QR, x + (CELL - QR) // 2:x + (CELL + QR) // 2] = cv2.cvtColor(qr, cv2.COLOR_GRAY2BGR)
        for text, dy, scale in ((it["asset_tag"], QR + 75, 1.1), (it["name"], QR + 115, 0.8)):
            (tw, _), _ = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, scale, 2)
            cv2.putText(sheet, text, (x + (CELL - tw) // 2, y + dy), cv2.FONT_HERSHEY_SIMPLEX, scale, (0, 0, 0), 2, cv2.LINE_AA)
        cv2.rectangle(sheet, (x, y), (x + CELL - 1, y + CELL - 1), (200, 200, 200), 1)
    cv2.imwrite(out, sheet)
    print(f"wrote {len(items)} labels to {out}")


if __name__ == "__main__":
    main(*sys.argv[1:])
