# Inventory backend

Minimal backend for the SPH / makerspace lending kiosk: Legi login, loan, return, and
"what's on the tray?" identification (QR labels now, YOLO vision later).

Python 3.13 · FastAPI · SQLite · OpenCV. Runs on the Pi next to the UI, on `127.0.0.1:8000`;
the Qt app talks to it over HTTP/JSON. Interactive API docs: http://127.0.0.1:8000/docs

## Run

    # Mac (dev): camera off unless KIOSK_CAMERA is set (0 = built-in webcam)
    uv venv -p 3.13 .venv && uv pip install -p .venv -r requirements-dev.txt
    .venv/bin/python -m pytest -q
    .venv/bin/uvicorn kiosk_backend.app:app --reload

    # Pi: systemd --user service "kiosk-backend", starts with the user session
    backend/deploy.sh                # sync, install, restart (PI_HOST=rishi@172.20.10.3 if mDNS is flaky)
    backend/deploy.sh logs|status|stop
    backend/deploy.sh reset          # wipe loans, reseed (between demo runs)
    backend/deploy.sh labels         # QR label sheet for all items → backend/labels.png
    backend/deploy.sh pin [NEW]      # show / set the staff PIN

Env: `KIOSK_DB` (default `data/inventory.db`), `KIOSK_CAMERA` (Linux: `/dev/video0`, retried until plugged in; Mac: `off`), `KIOSK_STAFF_PIN` (else `data/staff_pin`).

## API

| | |
|---|---|
| `POST /auth/card {uid}` | RFID tap. Unknown card → bound to the next mock user without a card (demo) |
| `POST /auth/legi {legi}` | typed Legi number, `21-912-345` or `21912345` |
| `GET /users/{id}/loans` | what this user currently has |
| `GET /items[?state=available\|loaned]` · `GET /items/{id}` · `GET /items/by-tag/{tag}` | |
| `POST /identify` | what's on the tray: live camera, or multipart `image` upload for testing |
| `GET /camera/frame.jpg?width=1024` | tray preview for the UI |
| `POST /loans {user_id, item_ids}` | check out, all-or-nothing; 409 + `problems[]` says what blocked it |
| `POST /returns {item_ids}` | check in, no login needed; reports borrower + overdue |
| `GET /loans` | open loans with full names (staff: `X-Staff-Pin`) |
| `POST /admin/reset` | reseed (staff: `X-Staff-Pin`) |
| `POST /staff/unlock {pin}` | check the staff PIN |

Errors are `{"error": "...", "problems": [{item_id, name, reason}]}`; the message is UI-ready.

`/identify` returns `qr_decoder` and `detections[]`, each with `method` (`qr` / `vision`), `bbox` (x, y, w, h
in camera pixels) and `items[]` — exactly one unit for a QR hit, every unit of that kind for a
vision hit (vision knows *what* it is, only QR knows *which* one), empty if the code isn't ours.

## Data

`kiosk_backend/schema.sql`: `users`, `items`, `loans` (a partial unique index makes a double
checkout impossible), `events` (audit log). Item availability is derived from open loans, not
stored. Mock users and the demo basket are in `kiosk_backend/seed.json` — edit to match the real
basket, then `deploy.sh && deploy.sh reset`. `vision_label` must match the YOLO class names.

## Public-kiosk safeguards

The server listens on 127.0.0.1 only; these protect against people at the touchscreen.

- **Staff PIN** (`security.py`): `GET /loans` (names of all borrowers) and `POST /admin/reset`
  need header `X-Staff-Pin`; `POST /staff/unlock {pin}` checks it for the UI. 5 wrong → locked 5 min.
  The PIN is `$KIOSK_STAFF_PIN` or `data/staff_pin` (random 6 digits on first start, mode 600):
  `deploy.sh pin` shows it, `deploy.sh pin 123456` sets it.
- **Minimal personal data**: login responses carry `name` as "Anna K." plus `first_name`, never the
  Legi number or email; returns name the borrower the same way. Full names only via `/loans`.
- **Legi guessing**: 5 unknown Legi numbers within 2 min → typed login paused for 1 min (429).
- `data/` (DB + PIN) is owner-only. Card UIDs are stored (needed for card login), not logged.

## QR labels

A label's QR code holds just its asset tag (`DAIM-001`); that string is `items.asset_tag`, so
there is no separate mapping table. Payloads are normalised: case, whitespace and a tag inside a
URL (`https://…/DAIM-001`) all resolve, and lookups ignore zero padding (`DAIM-7` = `DAIM-007`).
Any other QR code is reported with `items: []` and the UI shows it as "Unknown label".

Decoding uses zxing-cpp (OpenCV's reader is only a fallback if the wheel is missing): it reads the
current 25 mm labels (QR v1, 1.2 mm modules) at any rotation down to ~2.5 camera px per module,
i.e. ~2 px/mm on the tray. OpenCV needed ~5 px/module and still missed rotated codes. Keep at
least ~2 modules of white around each code. The printed sheet is `external/labels_test_outline.pdf`;
`python -m kiosk_backend.labels` makes plain fallback labels from the database.

## Vision (stub)

`kiosk_backend/vision.py` — implement `detect(image) -> list[Detection]` and set `ENABLED = True`.
