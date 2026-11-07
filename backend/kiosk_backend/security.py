"""Public-kiosk safeguards: staff PIN for staff-only endpoints, throttling of guessable logins.
(What personal data the public screen gets is decided in inventory.user_dict / return_items.)

The server only listens on 127.0.0.1, so these guard against people at the touchscreen
(the hidden staff panel, typing other people's Legi numbers), not against the network.
"""

import hmac
import logging
import os
import secrets
import threading
import time
from pathlib import Path

from fastapi import Header

from . import db
from .inventory import InventoryError

log = logging.getLogger(__name__)


class Throttle:
    """After `max_fails` failures within `window` s, refuse everything for `lockout` s."""

    def __init__(self, name: str, max_fails: int, window: float, lockout: float, message: str):
        self.name, self.max_fails, self.window, self.lockout, self.message = name, max_fails, window, lockout, message
        self._fails: list[float] = []
        self._locked_until = 0.0
        self._lock = threading.Lock()

    def check(self) -> None:
        with self._lock:
            if time.monotonic() < self._locked_until:
                raise InventoryError(429, self.message)

    def failed(self) -> None:
        with self._lock:
            t = time.monotonic()
            self._fails = [f for f in self._fails if t - f < self.window] + [t]
            if len(self._fails) >= self.max_fails:
                self._locked_until = t + self.lockout
                self._fails.clear()
                log.warning("%s locked for %.0f s after %d failures", self.name, self.lockout, self.max_fails)

    def succeeded(self) -> None:
        with self._lock:
            self._fails.clear()

    def clear(self) -> None:
        with self._lock:
            self._fails.clear()
            self._locked_until = 0.0


# One kiosk, one screen: throttles are global, not per client.
legi_throttle = Throttle("typed Legi sign-in", 5, 120, 60, "Too many wrong Legi numbers. Wait a minute, or tap your Legi card.")
staff_throttle = Throttle("staff PIN", 5, 300, 300, "Too many wrong PINs. Staff access is locked for 5 minutes.")


# ---------------------------------------------------------------- staff PIN

def _pin_file() -> Path:
    return db.DB_PATH.parent / "staff_pin"


def staff_pin() -> str:
    """$KIOSK_STAFF_PIN, else data/staff_pin (a random 6-digit PIN is created there on first use)."""
    if env := os.environ.get("KIOSK_STAFF_PIN", "").strip():
        return env
    path = _pin_file()
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(f"{secrets.randbelow(10**6):06d}\n")
        log.warning("created a staff PIN in %s (backend/deploy.sh pin shows or sets it)", path)
    return path.read_text().strip()


def check_staff_pin(pin: str | None) -> None:
    staff_throttle.check()
    if not pin or not hmac.compare_digest(pin.strip().encode(), staff_pin().encode()):
        staff_throttle.failed()
        raise InventoryError(401, "Wrong PIN")
    staff_throttle.succeeded()


def require_staff(x_staff_pin: str | None = Header(None)) -> None:
    """FastAPI dependency for staff-only endpoints: header `X-Staff-Pin`."""
    check_staff_pin(x_staff_pin)

