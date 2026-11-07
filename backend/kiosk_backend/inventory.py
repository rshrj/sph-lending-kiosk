"""Inventory rules: login, item lookup, loan, return. Pure functions over a sqlite3 connection."""

import re
import sqlite3
from datetime import UTC, datetime, timedelta

from . import db

DEMO_AUTO_ENROLL = True  # an unknown card is bound to the next mock user without a card


class InventoryError(Exception):
    def __init__(self, status: int, message: str, problems: list[dict] | None = None):
        super().__init__(message)
        self.status, self.message, self.problems = status, message, problems or []


# ---------------------------------------------------------------- users

def short_name(name: str) -> str:
    """'Anna Keller' -> 'Anna K.': enough to recognise yourself, not to identify someone else."""
    parts = name.split()
    return f"{parts[0]} {parts[-1][0]}." if len(parts) >= 2 else name


def user_dict(row: sqlite3.Row) -> dict:
    """The signed-in user as the public kiosk sees them: no Legi number, no email, short name.
    Full names only go to staff (GET /loans, behind the staff PIN)."""
    return {
        "id": row["id"],
        "name": short_name(row["name"]),
        "first_name": row["name"].split()[0],
        "role": row["role"],
        "has_card": row["card_uid"] is not None,
    }


def get_user(conn, user_id: int) -> sqlite3.Row:
    row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    if row is None:
        raise InventoryError(404, f"No user with id {user_id}")
    return row


def login_legi(conn, legi: str) -> dict:
    digits = db.normalize_legi(legi)
    if digits is None:
        raise InventoryError(422, "A Legi number has 8 digits, e.g. 21-912-345")
    row = conn.execute("SELECT * FROM users WHERE legi = ?", (digits,)).fetchone()
    if row is None:
        raise InventoryError(404, "Unknown Legi number")
    db.log_event(conn, "login", row["id"], method="legi")
    return user_dict(row)


def login_card(conn, uid: str) -> dict:
    norm = db.normalize_uid(uid)
    if norm is None:
        raise InventoryError(422, "Card UID must be 4-10 bytes of hex")
    row = conn.execute("SELECT * FROM users WHERE card_uid = ?", (norm,)).fetchone()
    if row is None and DEMO_AUTO_ENROLL:
        conn.execute("BEGIN IMMEDIATE")
        free = conn.execute("SELECT * FROM users WHERE card_uid IS NULL ORDER BY id LIMIT 1").fetchone()
        if free is not None:
            conn.execute("UPDATE users SET card_uid = ? WHERE id = ?", (norm, free["id"]))
            db.log_event(conn, "card_bound", free["id"], uid=norm)
        conn.execute("COMMIT")
        row = conn.execute("SELECT * FROM users WHERE card_uid = ?", (norm,)).fetchone()
    if row is None:
        raise InventoryError(404, "Unknown card. Type your Legi number instead.")
    db.log_event(conn, "login", row["id"], method="card")
    return user_dict(row)


# ---------------------------------------------------------------- items

_ITEM_SELECT = """
    SELECT i.*, l.user_id AS borrower_id, l.loaned_at, l.due_at
    FROM items i LEFT JOIN loans l ON l.item_id = i.id AND l.returned_at IS NULL
"""


def item_dict(row: sqlite3.Row) -> dict:
    if row["status"] != "active":
        state = row["status"]
    elif row["borrower_id"] is not None:
        state = "loaned"
    else:
        state = "available"
    d = {k: row[k] for k in ("id", "asset_tag", "name", "category", "vision_label", "location", "loan_days")}
    d["state"] = state
    if state == "loaned":
        d["loan"] = {"user_id": row["borrower_id"], "loaned_at": row["loaned_at"], "due_at": row["due_at"]}
    return d


def list_items(conn, state: str | None = None) -> list[dict]:
    items = [item_dict(r) for r in conn.execute(_ITEM_SELECT + " ORDER BY i.asset_tag")]
    return [i for i in items if state is None or i["state"] == state]


def get_item(conn, item_id: int) -> dict:
    row = conn.execute(_ITEM_SELECT + " WHERE i.id = ?", (item_id,)).fetchone()
    if row is None:
        raise InventoryError(404, f"No item with id {item_id}")
    return item_dict(row)


def find_by_tag(conn, tag: str) -> dict | None:
    """Exact asset tag (case-insensitive); else the same prefix and number, ignoring zero
    padding, so "daim-7" finds DAIM-007."""
    tag = tag.strip()
    row = conn.execute(_ITEM_SELECT + " WHERE i.asset_tag = ? COLLATE NOCASE", (tag,)).fetchone()
    if row is None and (m := re.fullmatch(r"([A-Za-z]+)-0*(\d+)", tag)):
        prefix, number = m.group(1).upper(), int(m.group(2))
        for r in conn.execute(_ITEM_SELECT + " WHERE i.asset_tag LIKE ? || '-%'", (prefix,)):
            tail = r["asset_tag"].split("-", 1)[1]
            if tail.isdigit() and int(tail) == number:
                row = r
                break
    return item_dict(row) if row else None


def find_by_vision_label(conn, label: str) -> list[dict]:
    return [item_dict(r) for r in conn.execute(_ITEM_SELECT + " WHERE i.vision_label = ? ORDER BY i.asset_tag", (label,))]


def user_loans(conn, user_id: int) -> list[dict]:
    get_user(conn, user_id)
    rows = conn.execute(_ITEM_SELECT + " WHERE l.user_id = ? ORDER BY l.due_at", (user_id,))
    return [item_dict(r) for r in rows]


# ---------------------------------------------------------------- loan / return

def _check_ids(item_ids: list[int]) -> None:
    if not item_ids:
        raise InventoryError(422, "No items given")
    if len(set(item_ids)) != len(item_ids):
        raise InventoryError(422, "The same item is listed twice")


def loan(conn, user_id: int, item_ids: list[int]) -> dict:
    """Check out all items to the user, or none of them (409 lists what blocked it)."""
    _check_ids(item_ids)
    conn.execute("BEGIN IMMEDIATE")
    try:
        user = get_user(conn, user_id)
        items, problems = [], []
        for iid in item_ids:
            row = conn.execute(_ITEM_SELECT + " WHERE i.id = ?", (iid,)).fetchone()
            if row is None:
                problems.append({"item_id": iid, "reason": "unknown item"})
                continue
            it = item_dict(row)
            if it["state"] == "loaned":
                reason = "you already have it" if it["loan"]["user_id"] == user_id else "already on loan"
                problems.append({"item_id": iid, "name": it["name"], "reason": reason})
            elif it["state"] != "available":
                problems.append({"item_id": iid, "name": it["name"], "reason": f"item is {it['state']}"})
            else:
                items.append(it)
        if problems:
            raise InventoryError(409, "Some items can't be loaned", problems)

        t = datetime.now(UTC).replace(microsecond=0)
        out = []
        for it in items:
            due = (t + timedelta(days=it["loan_days"])).isoformat()
            conn.execute(
                "INSERT INTO loans (item_id, user_id, loaned_at, due_at) VALUES (?, ?, ?, ?)",
                (it["id"], user_id, t.isoformat(), due),
            )
            db.log_event(conn, "loan", user_id, it["id"], due_at=due)
            out.append({**it, "state": "loaned", "loan": {"user_id": user_id, "loaned_at": t.isoformat(), "due_at": due}})
        conn.execute("COMMIT")
    except BaseException:
        conn.execute("ROLLBACK")
        raise
    return {"user": user_dict(user), "items": out}


def return_items(conn, item_ids: list[int]) -> dict:
    """Check in all items (whoever borrowed them), or none of them."""
    _check_ids(item_ids)
    conn.execute("BEGIN IMMEDIATE")
    try:
        found, problems = [], []
        for iid in item_ids:
            row = conn.execute(
                "SELECT l.id AS loan_id, l.due_at, i.name, u.id AS user_id, u.name AS user_name "
                "FROM items i LEFT JOIN loans l ON l.item_id = i.id AND l.returned_at IS NULL "
                "LEFT JOIN users u ON u.id = l.user_id WHERE i.id = ?", (iid,)).fetchone()
            if row is None:
                problems.append({"item_id": iid, "reason": "unknown item"})
            elif row["loan_id"] is None:
                problems.append({"item_id": iid, "name": row["name"], "reason": "not on loan"})
            else:
                found.append((iid, row))
        if problems:
            raise InventoryError(409, "Some items can't be returned", problems)

        t = db.now()
        out = []
        for iid, row in found:
            conn.execute("UPDATE loans SET returned_at = ? WHERE id = ?", (t, row["loan_id"]))
            overdue = t > row["due_at"]
            db.log_event(conn, "return", row["user_id"], iid, overdue=overdue)
            out.append({"item_id": iid, "name": row["name"], "borrower": {"id": row["user_id"], "name": short_name(row["user_name"])},
                        "due_at": row["due_at"], "overdue": overdue})
        conn.execute("COMMIT")
    except BaseException:
        conn.execute("ROLLBACK")
        raise
    return {"returned": out}


def open_loans(conn) -> list[dict]:
    rows = conn.execute(
        "SELECT l.*, i.asset_tag, i.name AS item_name, u.name AS user_name FROM loans l "
        "JOIN items i ON i.id = l.item_id JOIN users u ON u.id = l.user_id "
        "WHERE l.returned_at IS NULL ORDER BY l.due_at")
    t = db.now()
    return [{"loan_id": r["id"], "item_id": r["item_id"], "asset_tag": r["asset_tag"], "item_name": r["item_name"],
             "user_id": r["user_id"], "user_name": r["user_name"], "loaned_at": r["loaned_at"],
             "due_at": r["due_at"], "overdue": t > r["due_at"]} for r in rows]
