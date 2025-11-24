import sqlite3, datetime, uuid, json

def log_incident(event_type, description, correlation_id=None):
    conn = sqlite3.connect("custody/ledger.db")
    cursor = conn.cursor()
    incident_id = correlation_id or str(uuid.uuid4())
    payload = {"description": description}
    cursor.execute("""
        INSERT INTO ledger (timestamp_utc, timestamp_ct, event_type, level, actor_identity, payload, correlation_id, seal_version, environment)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        datetime.datetime.utcnow().isoformat(),
        datetime.datetime.now().isoformat(),
        event_type,
        "ERROR",
        "incident_logger",
        json.dumps(payload),
        incident_id,
        "MVP_v1",
        "dev"
    ))
    conn.commit()
    conn.close()
    return incident_id
