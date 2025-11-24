CREATE TABLE IF NOT EXISTS ledger (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_utc TEXT NOT NULL,
    timestamp_ct TEXT NOT NULL,
    event_type TEXT NOT NULL,
    level TEXT NOT NULL,
    actor_identity TEXT NOT NULL,
    payload TEXT,
    correlation_id TEXT,
    seal_version TEXT,
    environment TEXT
);
