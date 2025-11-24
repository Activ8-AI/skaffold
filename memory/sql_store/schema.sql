CREATE TABLE IF NOT EXISTS memory_store (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp_utc TEXT NOT NULL,
    actor_identity TEXT NOT NULL,
    memory_type TEXT NOT NULL,
    payload TEXT NOT NULL,
    correlation_id TEXT,
    seal_version TEXT,
    environment TEXT
);

CREATE TABLE IF NOT EXISTS vector_index (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    embedding BLOB NOT NULL,
    reference TEXT NOT NULL,
    correlation_id TEXT,
    seal_version TEXT,
    environment TEXT
);
