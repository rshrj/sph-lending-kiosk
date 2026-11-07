import importlib.util
import json
from pathlib import Path

import numpy as np
import pytest

from kiosk_backend import teach

STAFF = {"X-Staff-Pin": "4711"}


def tray(item_at=None, shift=0) -> np.ndarray:
    """A grey, slightly textured 1280×720 tray, optionally with a blue 'item' at (x, y)."""
    rng = np.random.default_rng(1)
    img = np.clip(170 + rng.normal(0, 3, (720, 1280, 3)) + shift, 0, 255).astype(np.uint8)
    if item_at:
        x, y = item_at
        img[y:y + 120, x:x + 200] = (200, 80, 30)
    return img


def test_capture_flow(tmp_path):
    t = teach.Teacher(tmp_path)
    assert t.capture("robot_wheel", tray((100, 100))).status == "no_background"
    t.set_background([tray(), tray()])
    assert t.counts() == {"_empty": 1}

    frame = tray((300, 200))
    assert t.capture("robot_wheel", frame).status == "moving"     # first look: nothing to compare yet
    r = t.capture("robot_wheel", frame)
    assert r.status == "saved" and r.count == 1
    x, y, w, h = r.bbox
    assert abs(x - 300) < 12 and abs(y - 200) < 12 and abs(w - 200) < 24 and abs(h - 120) < 24
    meta = json.loads(next((tmp_path / "robot_wheel").glob("*.json")).read_text())
    assert meta["label"] == "robot_wheel" and meta["size"] == [1280, 720]
    assert t.capture("robot_wheel", frame).status == "same"       # not moved: don't save a duplicate

    moved = tray((800, 400))
    assert t.capture("robot_wheel", moved).status == "moving"
    assert t.capture("robot_wheel", moved).status == "saved"
    assert t.counts()["robot_wheel"] == 2

    assert t.undo() == "robot_wheel" and t.counts()["robot_wheel"] == 1


def test_capture_empty_and_lighting(tmp_path):
    t = teach.Teacher(tmp_path)
    t.set_background([tray()])
    t.capture("x", tray())
    assert t.capture("x", tray()).status == "empty"
    brighter = tray(shift=25)                    # auto-exposure moved: still an empty tray
    t.capture("x", brighter)
    assert t.capture("x", brighter).status == "empty"


def test_labels_are_safe():
    assert teach.valid_label("cell_phone")
    for bad in ("../etc", "Cell Phone", "", "_empty", "a/b"):
        assert not teach.valid_label(bad)


@pytest.fixture
def teach_client(client, tmp_path, monkeypatch):
    from kiosk_backend import app as app_module
    monkeypatch.setattr(app_module, "teacher", teach.Teacher(tmp_path / "dataset"))
    frames = {"img": tray()}
    monkeypatch.setattr(app_module.camera, "frame", lambda: frames["img"])
    monkeypatch.setattr("time.sleep", lambda s: None)
    return client, frames


def test_teach_api(teach_client):
    client, frames = teach_client
    assert client.get("/teach/status").status_code == 401                 # staff only
    st = client.get("/teach/status", headers=STAFF).json()
    assert not st["background"] and any(k["label"] == "robot_wheel" for k in st["kinds"])
    assert client.post("/teach/capture", json={"label": "nope"}, headers=STAFF).status_code == 422

    assert client.post("/teach/background", headers=STAFF).status_code == 200
    frames["img"] = tray((500, 300))
    client.post("/teach/capture", json={"label": "robot_wheel"}, headers=STAFF)
    r = client.post("/teach/capture", json={"label": "robot_wheel"}, headers=STAFF).json()
    assert r["status"] == "saved" and r["count"] == 1 and r["image_size"] == [1280, 720]

    st = client.get("/teach/status", headers=STAFF).json()
    assert st["background"] and st["empty_photos"] == 1
    assert next(k for k in st["kinds"] if k["label"] == "robot_wheel")["count"] == 1
    assert client.post("/teach/undo", headers=STAFF).json() == {"label": "robot_wheel", "count": 0}


def test_teach_needs_camera(client):
    assert client.post("/teach/background", headers=STAFF).status_code == 503


def test_train_dataset_build(tmp_path):
    spec = importlib.util.spec_from_file_location("train", Path(__file__).parent.parent / "tools" / "train.py")
    train = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(train)

    t = teach.Teacher(tmp_path / "src")
    t.set_background([tray()])
    for i in range(12):
        f = tray((40 + i * 80, 100 + (i % 3) * 150))
        t.capture("robot_wheel", f)
        assert t.capture("robot_wheel", f).status == "saved"
    f = tray((300, 300))
    for _ in range(2):
        t.capture("caster_wheel", f)      # one photo only: below --min-photos

    ds = train.build_dataset(tmp_path / "src", tmp_path / "yolo", min_photos=10)
    assert ds["classes"] == ["robot_wheel"] and ds["skipped"] == {"caster_wheel": 1}
    assert ds["split"]["train"] + ds["split"]["val"] == 13 and ds["split"]["val"] >= 1
    label = next((tmp_path / "yolo" / "labels" / "train").glob("robot_wheel-*.txt")).read_text().split()
    assert label[0] == "0" and all(0 < float(v) < 1 for v in label[1:])
    assert "0: robot_wheel" in ds["yaml"].read_text()
