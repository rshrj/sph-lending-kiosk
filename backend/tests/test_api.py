import os

import cv2
import numpy as np
import pytest

os.environ["KIOSK_CAMERA"] = "off"


STAFF = {"X-Staff-Pin": "4711"}


@pytest.fixture
def client(tmp_path, monkeypatch):
    from kiosk_backend import db, security
    monkeypatch.setattr(db, "DB_PATH", tmp_path / "test.db")
    monkeypatch.setenv("KIOSK_STAFF_PIN", "4711")
    security.legi_throttle.clear()
    security.staff_throttle.clear()
    from fastapi.testclient import TestClient
    from kiosk_backend.app import app
    with TestClient(app) as c:
        yield c


def ids(client, *tags):
    return [client.get(f"/items/by-tag/{t}").json()["id"] for t in tags]


def test_legi_login(client):
    r = client.post("/auth/legi", json={"legi": "21912345"})
    assert r.status_code == 200 and r.json()["name"] == "Anna K." and r.json()["first_name"] == "Anna"
    assert not {"legi", "email"} & r.json().keys()   # never sent to the public screen
    assert client.post("/auth/legi", json={"legi": "99-999-999"}).status_code == 404
    assert client.post("/auth/legi", json={"legi": "123"}).status_code == 422


def test_card_auto_enroll(client):
    a = client.post("/auth/card", json={"uid": "04:a3:1b:22"}).json()
    b = client.post("/auth/card", json={"uid": "04A31B22"}).json()
    c = client.post("/auth/card", json={"uid": "DEADBEEF"}).json()
    assert a["id"] == b["id"] != c["id"] and a["has_card"]


def test_loan_and_return(client):
    user = client.post("/auth/legi", json={"legi": "21-912-345"}).json()
    other = client.post("/auth/legi", json={"legi": "22-845-102"}).json()
    mm, iron = ids(client, "DAIM-001", "DAIM-002")

    r = client.post("/loans", json={"user_id": user["id"], "item_ids": [mm, iron]})
    assert r.status_code == 200, r.text
    assert {i["state"] for i in r.json()["items"]} == {"loaned"}
    assert len(client.get(f"/users/{user['id']}/loans").json()) == 2
    assert len(client.get("/items", params={"state": "available"}).json()) == 5

    # all-or-nothing: one unavailable item blocks the whole loan
    free = ids(client, "DAIM-003")[0]
    r = client.post("/loans", json={"user_id": other["id"], "item_ids": [free, mm]})
    assert r.status_code == 409 and r.json()["problems"][0]["reason"] == "already on loan"
    assert client.get(f"/items/{free}").json()["state"] == "available"

    r = client.post("/returns", json={"item_ids": [mm]})
    assert r.status_code == 200 and r.json()["returned"][0]["borrower"]["name"] == "Anna K."
    assert client.post("/returns", json={"item_ids": [mm]}).status_code == 409
    assert [i["asset_tag"] for i in client.get(f"/users/{user['id']}/loans").json()] == ["DAIM-002"]
    assert len(client.get("/loans", headers=STAFF).json()) == 1

    client.post("/admin/reset", headers=STAFF)
    assert client.get("/loans", headers=STAFF).json() == []


def qr_image(tag: str, module_px: float) -> np.ndarray:
    code = cv2.QRCodeEncoder.create().encode(tag)
    size = round(code.shape[0] * module_px)
    return cv2.cvtColor(cv2.resize(code, (size, size), interpolation=cv2.INTER_NEAREST), cv2.COLOR_GRAY2BGR)


def post_image(client, img):
    jpg = cv2.imencode(".jpg", img)[1].tobytes()
    r = client.post("/identify", files={"image": ("tray.jpg", jpg, "image/jpeg")})
    assert r.status_code == 200, r.text
    return r.json()


def test_identify_qr_upload(client):
    canvas = np.full((900, 1600, 3), 255, np.uint8)
    for k, tag in enumerate(["DAIM-003", "https://example.org/item/daim-005", "NOT-OURS"]):
        canvas[200:500, 100 + k * 500:400 + k * 500] = cv2.resize(qr_image(tag, 10), (300, 300))
    res = post_image(client, canvas)
    found = {d["code"]: d["items"] for d in res["detections"]}
    assert found["DAIM-003"][0]["name"] == "DC power adapter"
    assert found["DAIM-005"][0]["name"] == "Robot wheel"     # tag pulled out of a URL payload
    assert found["NOT-OURS"] == []


def test_identify_small_rotated_labels(client):
    # Overhead webcam view: ~3 px per QR module, labels at arbitrary angles, soft and noisy.
    canvas = np.full((1080, 1920, 3), 235, np.uint8)
    for k, angle in enumerate([0, 23, 45, 70, 160, 290, 330]):
        qr = qr_image(f"DAIM-00{k + 1}", 3)
        qr = cv2.copyMakeBorder(qr, 20, 20, 20, 20, cv2.BORDER_CONSTANT, value=(255, 255, 255))
        h, w = qr.shape[:2]
        rot = cv2.warpAffine(qr, cv2.getRotationMatrix2D((w / 2, h / 2), angle, 1), (w, h), borderValue=(235, 235, 235))
        x, y = 150 + (k % 4) * 420, 200 + (k // 4) * 450
        canvas[y:y + h, x:x + w] = rot
    canvas = cv2.GaussianBlur(canvas, (0, 0), 0.6)
    canvas = np.clip(canvas + np.random.default_rng(0).normal(0, 4, canvas.shape), 0, 255).astype(np.uint8)
    res = post_image(client, canvas)
    assert res["qr_decoder"] == "zxing-cpp"
    assert sorted(d["code"] for d in res["detections"]) == [f"DAIM-00{i}" for i in range(1, 8)]
    assert all(d["items"] for d in res["detections"])


def test_tag_lookup_is_lenient(client):
    for t in ("DAIM-007", "daim-007", " DAIM-7 ", "DAIM-0007"):
        r = client.get(f"/items/by-tag/{t}")
        assert r.status_code == 200 and r.json()["asset_tag"] == "DAIM-007", t
    assert client.get("/items/by-tag/DAIM-8").status_code == 404
    assert client.get("/items/by-tag/XYZ-001").status_code == 404


def test_normalize_code():
    from kiosk_backend.identify import normalize_code
    assert normalize_code("DAIM-001") == "DAIM-001"
    assert normalize_code(" daim-001\n") == "DAIM-001"
    assert normalize_code("https://sph.ethz.ch/inventory/DAIM-004?x=1") == "DAIM-004"
    assert normalize_code("hello world") == "hello world"


def test_identify_without_camera(client):
    assert client.post("/identify").status_code == 503


def test_concurrent_requests(client):
    # The UI fires lookups in parallel; a per-request connection must survive FastAPI
    # handing the dependency and the endpoint to different threadpool threads.
    from concurrent.futures import ThreadPoolExecutor
    tags = [f"DAIM-00{i}" for i in range(1, 8)] * 4
    with ThreadPoolExecutor(8) as pool:
        codes = list(pool.map(lambda t: client.get(f"/items/by-tag/{t}").status_code, tags))
    assert codes == [200] * len(tags)


def test_staff_endpoints_need_pin(client):
    assert client.get("/loans").status_code == 401
    assert client.get("/loans", headers={"X-Staff-Pin": "0000"}).status_code == 401
    assert client.post("/admin/reset").status_code == 401
    assert client.post("/staff/unlock", json={"pin": "4711"}).json() == {"ok": True}
    assert client.get("/loans", headers=STAFF).status_code == 200


def test_staff_pin_lockout(client):
    for _ in range(5):
        assert client.post("/staff/unlock", json={"pin": "1234"}).status_code == 401
    r = client.post("/staff/unlock", json={"pin": "4711"})        # right PIN, but locked out
    assert r.status_code == 429 and "locked" in r.json()["error"]


def test_staff_pin_file_created(client, monkeypatch, tmp_path):
    from kiosk_backend import security
    monkeypatch.delenv("KIOSK_STAFF_PIN")
    pin = security.staff_pin()
    f = tmp_path / "staff_pin"
    assert len(pin) == 6 and pin.isdigit() and f.read_text().strip() == pin
    assert f.stat().st_mode & 0o077 == 0                           # owner-only
    assert security.staff_pin() == pin                             # stable


def test_legi_guessing_is_throttled(client):
    for n in range(5):
        assert client.post("/auth/legi", json={"legi": f"99-999-99{n}"}).status_code == 404
    r = client.post("/auth/legi", json={"legi": "21-912-345"})     # a real one, still locked
    assert r.status_code == 429 and "Wait a minute" in r.json()["error"]
