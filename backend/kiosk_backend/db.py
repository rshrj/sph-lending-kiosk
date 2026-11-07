"""SQLite access: connection setup, schema, seeding."""

import json
import os
import re
import sqlite3
from datetime import UTC, datetime
from pathlib import Path

PKG = Path(__file__).parent
DB_PATH = Path(os.environ.get("KIOSK_DB", PKG.parent / "data" / "inventory.db"))


def now() -> str:
    return datetime.now(UTC).isoformat(timespec="seconds")


def connect(path: Path | None = None) -> sqlite3.Connection:
    path = path or DB_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    # autocommit; explicit BEGIN for writes. One connection per request, but FastAPI may open it
    # (sync dependency) and use it (sync endpoint) on different threadpool threads.
    conn = sqlite3.connect(path, timeout=5, isolation_level=None, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")
    return conn


def normalize_legi(raw: str) -> str | None:
    """'12-345-678', '12345678', ' 12 345 678 ' -> '12345678'; anything else -> None."""
    digits = re.sub(r"[\s-]", "", raw)
    return digits if re.fullmatch(r"\d{8}", digits) else None


def format_legi(digits: str) -> str:
    return f"{digits[:2]}-{digits[2:5]}-{digits[5:]}"


def normalize_uid(raw: str) -> str | None:
    """'04:a3:1b:22', '04 A3 1B 22', '04a31b22' -> '04A31B22'."""
    hexs = re.sub(r"[\s:-]", "", raw).upper()
    return hexs if re.fullmatch(r"[0-9A-F]{8,20}", hexs) else None


def log_event(conn: sqlite3.Connection, kind: str, user_id=None, item_id=None, **detail) -> None:
    conn.execute(
        "INSERT INTO events (at, kind, user_id, item_id, detail) VALUES (?, ?, ?, ?, ?)",
        (now(), kind, user_id, item_id, json.dumps(detail) if detail else None),
    )


def init(conn: sqlite3.Connection, seed_if_empty: bool = True) -> None:
    conn.executescript((PKG / "schema.sql").read_text())
    if seed_if_empty and conn.execute("SELECT COUNT(*) FROM users").fetchone()[0] == 0:
        seed(conn)


def seed(conn: sqlite3.Connection) -> None:
    data = json.loads((PKG / "seed.json").read_text())
    conn.execute("BEGIN")
    for u in data["users"]:
        conn.execute(
            "INSERT INTO users (legi, card_uid, name, email, role) VALUES (?, ?, ?, ?, ?)",
            (normalize_legi(u["legi"]), u.get("card_uid"), u["name"], u.get("email"), u.get("role", "student")),
        )
    for it in data["items"]:
        conn.execute(
            "INSERT INTO items (asset_tag, name, category, vision_label, location, loan_days, notes) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (it["asset_tag"], it["name"], it.get("category", "misc"), it.get("vision_label"),
             it.get("location"), it.get("loan_days", 7), it.get("notes")),
        )
    conn.execute("COMMIT")


def reset(conn: sqlite3.Connection) -> None:
    """Wipe everything and reseed (demo reset)."""
    conn.execute("BEGIN")
    for table in ("events", "loans", "items", "users"):
        conn.execute(f"DELETE FROM {table}")
    conn.execute("COMMIT")
    seed(conn)
    log_event(conn, "reset")
