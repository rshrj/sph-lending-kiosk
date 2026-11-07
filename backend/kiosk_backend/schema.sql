-- Inventory database (SQLite). Applied on startup; every statement is idempotent.

CREATE TABLE IF NOT EXISTS users (
    id        INTEGER PRIMARY KEY,
    legi      TEXT NOT NULL UNIQUE,          -- 8 digits, no dashes (displayed as 12-345-678)
    card_uid  TEXT UNIQUE,                   -- RFID UID, uppercase hex; NULL until a card is bound
    name      TEXT NOT NULL,
    email     TEXT,
    role      TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'staff'))
);

CREATE TABLE IF NOT EXISTS items (
    id            INTEGER PRIMARY KEY,
    asset_tag     TEXT NOT NULL UNIQUE,      -- what the QR label encodes, e.g. DAIM-001
    name          TEXT NOT NULL,
    category      TEXT NOT NULL DEFAULT 'misc',
    vision_label  TEXT,                      -- class name the vision model emits for this kind of item
    location      TEXT,                      -- where it lives when not on loan
    loan_days     INTEGER NOT NULL DEFAULT 7,
    status        TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'missing', 'retired')),
    notes         TEXT
);
CREATE INDEX IF NOT EXISTS items_vision_label ON items (vision_label);

CREATE TABLE IF NOT EXISTS loans (
    id           INTEGER PRIMARY KEY,
    item_id      INTEGER NOT NULL REFERENCES items (id),
    user_id      INTEGER NOT NULL REFERENCES users (id),
    loaned_at    TEXT NOT NULL,              -- ISO 8601 UTC
    due_at       TEXT NOT NULL,
    returned_at  TEXT
);
-- At most one open loan per item: the database itself refuses a double checkout.
CREATE UNIQUE INDEX IF NOT EXISTS loans_one_open_per_item ON loans (item_id) WHERE returned_at IS NULL;
CREATE INDEX IF NOT EXISTS loans_user ON loans (user_id, returned_at);

-- Append-only audit log.
CREATE TABLE IF NOT EXISTS events (
    id       INTEGER PRIMARY KEY,
    at       TEXT NOT NULL,
    kind     TEXT NOT NULL,                  -- login, loan, return, card_bound, reset
    user_id  INTEGER REFERENCES users (id),
    item_id  INTEGER REFERENCES items (id),
    detail   TEXT                            -- JSON
);
