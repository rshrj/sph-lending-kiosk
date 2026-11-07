"""HTTP API for the kiosk. Run: uvicorn kiosk_backend.app:app --host 127.0.0.1 --port 8000"""

import logging
import time
from contextlib import asynccontextmanager

import cv2
import numpy as np
from fastapi import Depends, FastAPI, File, HTTPException, Request, UploadFile
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel, Field

from . import db, identify as ident, inventory, security, teach, vision
from .camera import Camera
from .inventory import InventoryError

# One line per event; the journal adds time and unit. No names, Legi numbers, card UIDs or PINs
# in the log: users appear by database id only.
logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")
log = logging.getLogger("kiosk")
camera = Camera()
teacher = teach.Teacher()


@asynccontextmanager
async def lifespan(app: FastAPI):
    conn = db.connect()
    db.init(conn)
    conn.close()
    security.staff_pin()  # create data/staff_pin on first start, so deploy.sh pin/reset work
    conn = db.connect()
    n_items = conn.execute("SELECT COUNT(*) FROM items").fetchone()[0]
    n_loans = conn.execute("SELECT COUNT(*) FROM loans WHERE returned_at IS NULL").fetchone()[0]
    conn.close()
    vision.load()
    log.info("backend %s up: db %s (%d items, %d open loans), camera %s, QR decoder %s, vision %s",
             app.version, db.DB_PATH, n_items, n_loans, camera.device, ident.decoder_name(),
             "on" if vision.ENABLED else "off")
    camera.start()
    yield
    camera.stop()


app = FastAPI(title="SPH inventory kiosk", version="0.1", lifespan=lifespan)


def get_conn():
    conn = db.connect()
    try:
        yield conn
    finally:
        conn.close()


@app.exception_handler(InventoryError)
async def inventory_error(request: Request, e: InventoryError):
    reasons = "; ".join(f"{p.get('name') or p.get('item_id')}: {p['reason']}" for p in e.problems)
    log.log(logging.WARNING if e.status in (401, 429) else logging.INFO,
            "refused %s %s (%d): %s%s", request.method, request.url.path, e.status, e.message,
            f" [{reasons}]" if reasons else "")
    return JSONResponse(status_code=e.status, content={"error": e.message, "problems": e.problems})


# Polled every second or so by the UI; logged only when slow or failing.
_QUIET = {"/health", "/camera/frame.jpg", "/identify", "/teach/capture"}


@app.middleware("http")
async def log_requests(request: Request, call_next):
    t0 = time.perf_counter()
    try:
        response = await call_next(request)
    except Exception:
        log.exception("%s %s crashed after %.0f ms", request.method, request.url.path, (time.perf_counter() - t0) * 1000)
        raise
    ms = (time.perf_counter() - t0) * 1000
    status = response.status_code
    if status >= 500:
        level = logging.ERROR
    elif ms > 2000:
        level = logging.WARNING
    elif request.url.path in _QUIET and status < 400:
        return response
    else:
        level = logging.INFO
    log.log(level, "%s %s -> %d (%.0f ms)", request.method, request.url.path, status, ms)
    return response


# ---------------------------------------------------------------- models

class LegiLogin(BaseModel):
    legi: str = Field(examples=["21-912-345"])


class CardLogin(BaseModel):
    uid: str = Field(examples=["04A31B22"])


class LoanRequest(BaseModel):
    user_id: int
    item_ids: list[int]


class ReturnRequest(BaseModel):
    item_ids: list[int]


# ---------------------------------------------------------------- routes

@app.get("/health")
def health():
    return {"ok": True, "camera": {"device": camera.device, "ready": camera.ready}}


@app.post("/auth/legi")
def auth_legi(body: LegiLogin, conn=Depends(get_conn)):
    # A typed Legi number is not a secret, so guessing is throttled (5 misses → 1 min lockout).
    security.legi_throttle.check()
    try:
        user = inventory.login_legi(conn, body.legi)
    except InventoryError as e:
        if e.status == 404:
            security.legi_throttle.failed()
        raise
    security.legi_throttle.succeeded()
    log.info("sign-in: user %d (typed Legi)", user["id"])
    return user


@app.post("/auth/card")
def auth_card(body: CardLogin, conn=Depends(get_conn)):
    user = inventory.login_card(conn, body.uid)
    log.info("sign-in: user %d (card)", user["id"])
    return user


@app.get("/users/{user_id}/loans")
def user_loans(user_id: int, conn=Depends(get_conn)):
    return inventory.user_loans(conn, user_id)


@app.get("/items")
def items(state: str | None = None, conn=Depends(get_conn)):
    return inventory.list_items(conn, state)


@app.get("/items/by-tag/{tag}")
def item_by_tag(tag: str, conn=Depends(get_conn)):
    item = inventory.find_by_tag(conn, tag)
    if item is None:
        raise HTTPException(404, f"No item tagged {tag}")
    return item


@app.get("/items/{item_id}")
def item(item_id: int, conn=Depends(get_conn)):
    return inventory.get_item(conn, item_id)


@app.post("/loans")
def create_loan(body: LoanRequest, conn=Depends(get_conn)):
    res = inventory.loan(conn, body.user_id, body.item_ids)
    log.info("loan: user %d took %s", body.user_id,
             ", ".join(f"{i['asset_tag']} (due {i['loan']['due_at'][:10]})" for i in res["items"]))
    return res


@app.get("/loans", dependencies=[Depends(security.require_staff)])
def list_open_loans(conn=Depends(get_conn)):
    """All open loans with borrowers' full names (staff only: header X-Staff-Pin)."""
    return inventory.open_loans(conn)


@app.post("/returns")
def create_return(body: ReturnRequest, conn=Depends(get_conn)):
    res = inventory.return_items(conn, body.item_ids)
    log.info("return: %s", ", ".join(
        f"{r['name']} from user {r['borrower']['id']}{' (overdue)' if r['overdue'] else ''}" for r in res["returned"]))
    return res


def _camera_frame() -> np.ndarray:
    img = camera.frame()
    if img is None:
        raise HTTPException(503, "Camera not available")
    return img


@app.post("/identify")
def identify(image: UploadFile | None = File(None), conn=Depends(get_conn)):
    """Identify items on the tray: from the live camera, or from an uploaded image (testing)."""
    if image is not None:
        img = cv2.imdecode(np.frombuffer(image.file.read(), np.uint8), cv2.IMREAD_COLOR)
        if img is None:
            raise HTTPException(422, "Could not decode the uploaded image")
    else:
        img = _camera_frame()
    return ident.identify(conn, img)


@app.get("/camera/frame.jpg")
def camera_frame(width: int = 1024):
    """Current tray image, downscaled for the UI preview."""
    img = _camera_frame()
    h, w = img.shape[:2]
    if 0 < width < w:
        img = cv2.resize(img, (width, round(h * width / w)), interpolation=cv2.INTER_AREA)
    ok, jpg = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 80])
    return Response(jpg.tobytes(), media_type="image/jpeg", headers={"Cache-Control": "no-store"})


class StaffPin(BaseModel):
    pin: str


@app.post("/staff/unlock")
def staff_unlock(body: StaffPin):
    """Check the staff PIN (the UI then sends it as X-Staff-Pin). 5 wrong → locked 5 min."""
    security.check_staff_pin(body.pin)
    log.warning("staff panel unlocked")
    return {"ok": True}


@app.post("/admin/reset", dependencies=[Depends(security.require_staff)])
def admin_reset(conn=Depends(get_conn)):
    """Wipe loans/events and reseed users + items (between demo runs). Staff only."""
    log.warning("inventory reset (all loans cleared, reseeded)")
    db.reset(conn)
    return {"ok": True}


# ---------------------------------------------------------------- teach mode (staff)
# Collect labelled photos for training the vision model; see teach.py and tools/train.py.

def _kinds(conn) -> dict[str, list[str]]:
    """vision_label -> item names, for every kind in the inventory."""
    kinds: dict[str, list[str]] = {}
    for r in conn.execute("SELECT vision_label, name FROM items WHERE vision_label IS NOT NULL ORDER BY vision_label, asset_tag"):
        names = kinds.setdefault(r["vision_label"], [])
        if r["name"] not in names:
            names.append(r["name"])
    return kinds


@app.get("/teach/status", dependencies=[Depends(security.require_staff)])
def teach_status(conn=Depends(get_conn)):
    counts = teacher.counts()
    model = vision.info()
    return {
        "background": teacher.has_background,
        "empty_photos": counts.get(teach.EMPTY, 0),
        "kinds": [{"label": label, "names": names, "count": counts.get(label, 0), "in_model": label in model["labels"]}
                  for label, names in _kinds(conn).items()],
        "vision": model,
    }


@app.post("/teach/background", dependencies=[Depends(security.require_staff)])
def teach_background():
    """Photograph the empty tray (the reference every item photo is compared against)."""
    frames = []
    for _ in range(5):
        frames.append(_camera_frame())
        time.sleep(0.08)
    teacher.set_background(frames)
    log.info("teach: empty tray photographed")
    return {"ok": True}


class TeachCapture(BaseModel):
    label: str


@app.post("/teach/capture", dependencies=[Depends(security.require_staff)])
def teach_capture(body: TeachCapture, conn=Depends(get_conn)):
    """Called about every 0.7 s while recording; saves a photo when the item is still and has moved."""
    if not teach.valid_label(body.label) or body.label not in _kinds(conn):
        raise InventoryError(422, f"Unknown kind {body.label!r}")
    img = _camera_frame()
    r = teacher.capture(body.label, img)
    if r.status == "saved":
        log.info("teach: %s photo %d", body.label, r.count)
    h, w = img.shape[:2]
    return {"status": r.status, "message": r.message, "bbox": r.bbox, "count": r.count, "image_size": [w, h]}


@app.post("/teach/undo", dependencies=[Depends(security.require_staff)])
def teach_undo():
    label = teacher.undo()
    if label is None:
        raise InventoryError(409, "Nothing to undo")
    log.info("teach: removed the last %s photo", label)
    return {"label": label, "count": teacher.counts().get(label, 0)}
