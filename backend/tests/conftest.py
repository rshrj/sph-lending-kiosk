import os

import pytest

os.environ["KIOSK_CAMERA"] = "off"
os.environ.pop("KIOSK_VISION", None)


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
