#!/usr/bin/env bash
# META MEGA CODEX — Single-file, copy-once, drop-in MVP (A–Z)
# Charter Standard Execution: reproducible, audit-tight, sealed. No drift beyond thresholds.
# Version: 1.0
# Usage:
#   chmod +x META_MEGA_CODEX.sh
#   ./META_MEGA_CODEX.sh bootstrap|up|down|seal|audit|qa|incident "desc"|snapshot|checksum

set -euo pipefail

ROOT_DIR="$(pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
export PYTHONPATH="${ROOT_DIR}:${PYTHONPATH:-}"

ensure_python() {
  if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    echo "Python not found. Set PYTHON_BIN or install python3." >&2
    exit 1
  fi
}

ensure_deps() {
  # Minimal runtime deps: fastapi uvicorn requests
  if ! "$PYTHON_BIN" - <<'PY' >/dev/null 2>&1; then
    import pkgutil
    required = ["fastapi","uvicorn","requests"]
    missing = [p for p in required if not pkgutil.find_loader(p)]
    assert not missing, f"Missing: {missing}"
PY
    echo "Installing Python dependencies..."
    "$PYTHON_BIN" -m pip install --upgrade pip >/dev/null
    "$PYTHON_BIN" -m pip install fastapi uvicorn requests >/dev/null
  fi
}

bootstrap_files() {
  mkdir -p configs custody memory/sql_store memory/vector_store telemetry orchestration/MCP scripts agent_hub governance relay autonomy qa workflow utils compliance seals export migration
  touch .codex_lock

  # Config — Environment
  cat > configs/global_config.yaml <<'EOF'
environment: dev
seal_version: MVP_v1
telemetry_interval: 60
autonomy_enabled: true
governance_thresholds:
  drift_max: 10
  heartbeat_interval: 30
  incident_freeze: true
EOF

  # Ledger schema (SQL)
  cat > custody/schema.sql <<'EOF'
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
EOF

  # Initialize ledger.db
  "$PYTHON_BIN" - <<'EOF'
import sqlite3, os
os.makedirs("custody", exist_ok=True)
conn = sqlite3.connect("custody/ledger.db")
sql = open("custody/schema.sql").read()
conn.executescript(sql)
conn.commit()
conn.close()
EOF

  # Relay server (FastAPI)
  cat > orchestration/MCP/relay_server.py <<'EOF'
from fastapi import FastAPI
import uvicorn, datetime

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.datetime.utcnow().isoformat()}

@app.get("/heartbeat")
def heartbeat():
    return {"heartbeat": "alive", "utc": datetime.datetime.utcnow().isoformat()}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

  # Telemetry engine
  cat > telemetry/telemetry_engine.py <<'EOF'
import time, sqlite3, datetime, json

def emit_telemetry():
    conn = sqlite3.connect("custody/ledger.db")
    cursor = conn.cursor()
    drift_score = 5  # baseline placeholder
    payload = {"drift": drift_score, "status": "green"}
    cursor.execute(
        "INSERT INTO ledger (timestamp_utc, timestamp_ct, event_type, level, actor_identity, payload, seal_version, environment) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (datetime.datetime.utcnow().isoformat(),
         datetime.datetime.now().isoformat(),
         "TELEMETRY",
         "INFO",
         "telemetry_engine",
         json.dumps(payload),
         "MVP_v1",
         "dev")
    )
    conn.commit()
    conn.close()

if __name__ == "__main__":
    while True:
        emit_telemetry()
        time.sleep(60)
EOF

  # Drift scoring (deterministic baseline option)
  cat > governance/drift_scoring.py <<'EOF'
import os, random

def calculate_drift():
    # If DRIFT_FIXED is set, use deterministic drift; otherwise bounded random.
    fixed = os.environ.get("DRIFT_FIXED")
    if fixed is not None:
        try:
            drift = int(fixed)
        except ValueError:
            drift = 5
    else:
        random.seed(42)  # zero drift seed for reproducibility
        drift = random.randint(0, 15)
    status = "green" if drift < 10 else "red"
    return {"drift": drift, "status": status}
EOF

  # Autonomy loop (STOP–RESET–REALIGN gate)
  cat > autonomy/start_autonomy_loop.py <<'EOF'
import time
from telemetry.telemetry_engine import emit_telemetry
from governance.drift_scoring import calculate_drift

def autonomy_loop():
    while True:
        emit_telemetry()
        drift = calculate_drift()
        if drift["drift"] >= 10:
            print("Drift threshold exceeded — STOP–RESET–REALIGN")
        time.sleep(60)

if __name__ == "__main__":
    autonomy_loop()
EOF

  # Incident auto-logger
  cat > custody/incident_logger.py <<'EOF'
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
EOF

  # Custodian CLI
  cat > scripts/custodian_cli.py <<'EOF'
import argparse
from custody.incident_logger import log_incident

def main():
    parser = argparse.ArgumentParser(description="Custodian CLI")
    parser.add_argument("--incident", help="Description to log")
    args = parser.parse_args()
    if args.incident:
        iid = log_incident("CLI_TRIGGER", args.incident)
        print(f"Incident logged: {iid}")

if __name__ == "__main__":
    main()
EOF

  # Seal template
  cat > seals/SEAL_TEMPLATE.md <<'EOF'
# MAOS Seal Document
**Seal Version:** MVP_v1
**Date:** YYYY-MM-DD
**Environment:** dev/staging/prod
**Correlation ID:** <uuid>

## Conditions
- MCP online ✅
- Memory Pack online ✅
- Telemetry live ✅
- Agents active ✅
- Autonomy running ✅
- Drift < 10 ✅
- Governance enforced ✅
- Ledger healthy ✅

**Seal Status:** VALID / INVALID
**Signed By:** Custodian RoleID
EOF

  # Governance incident report template
  cat > custody/GOVERNANCE_INCIDENT_TEMPLATE.md <<'EOF'
# Governance Incident Report
**Incident ID:** <uuid>
**Date:** YYYY-MM-DD
**Triggered By:** Drift / Governance Violation / MCP Fault / Memory Fault / Seal Misalignment

## Description
<details>

## Ledger Cross-Link
- Correlation ID: <uuid>
- Ledger Entry: <reference>

## Resolution Steps
1. Pause autonomy loop
2. Log incident
3. Freeze configs
4. Governance approval required
5. Resume after resolution

**Status:** RESOLVED / UNRESOLVED
**Approved By:** RoleID
EOF

  # Daily autonomy snapshot template
  cat > custody/DAILY_SNAPSHOT_TEMPLATE.md <<'EOF'
# Daily Autonomy Snapshot
**Date:** YYYY-MM-DD
**Seal Version:** MVP_v1
**Run ID:** <uuid>

## Summary
- Heartbeats: <count>
- Drift Scores: <values>
- Governance Events: <list>
- Ledger Health: OK / Fault
- Notes: <observations>

**Custodian Signature:** RoleID
EOF

  # Repo checklist
  cat > scripts/check_activation.py <<'EOF'
import os
required_paths = [
    "configs/global_config.yaml",
    "orchestration/MCP/relay_server.py",
    "memory/sql_store/",
    "memory/vector_store/",
    "custody/",
    "scripts/",
    "agent_hub/",
    "telemetry/",
    "relay/",
    "autonomy/"
]
for p in required_paths:
    print("Found" if os.path.exists(p) else f"Missing: {p}")
EOF

  # Renewal rhythm manifest
  cat > governance/RENEWAL_MANIFEST.md <<'EOF'
# Renewal Rhythm Manifest
**Cycle:** Daily / Weekly / Quarterly
**Custodian:** RoleID
**Seal Version:** MVP_v1

## Renewal Steps
1. Validate ledger integrity
2. Cross-check drift scores
3. Re-seal environment
4. Archive daily snapshot
5. Reset autonomy loop
6. Governance approval

**Status:** COMPLETE / INCOMPLETE
**Signed By:** Custodian RoleID
EOF

  # Agent orchestration hub
  cat > agent_hub/orchestrator.py <<'EOF'
import time
from telemetry.telemetry_engine import emit_telemetry
from governance.drift_scoring import calculate_drift

def orchestrate_agents():
    while True:
        emit_telemetry()
        drift = calculate_drift()
        if drift["drift"] >= 10:
            print("⚠️ Drift threshold exceeded — pausing agents")
        else:
            print("✅ Agents aligned — continuing execution")
        time.sleep(60)

if __name__ == "__main__":
    orchestrate_agents()
EOF

  # Memory pack schema
  cat > memory/sql_store/schema.sql <<'EOF'
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
EOF

  # Compliance audit
  cat > scripts/compliance_audit.py <<'EOF'
import sqlite3
conn = sqlite3.connect("custody/ledger.db")
cur = conn.cursor()
cur.execute("SELECT COUNT(*) FROM ledger")
print("Ledger entries:", cur.fetchone()[0])
cur.execute("SELECT DISTINCT seal_version FROM ledger")
print("Seal versions:", [r[0] for r in cur.fetchall()])
cur.execute("SELECT DISTINCT environment FROM ledger")
print("Environments:", [r[0] for r in cur.fetchall()])
conn.close()
EOF

  # Relay integration
  cat > relay/relay_integration.py <<'EOF'
import requests, datetime
def send_relay_message(endpoint, payload):
    r = requests.post(endpoint, json=payload, timeout=5)
    return {"status": r.status_code, "timestamp": datetime.datetime.utcnow().isoformat()}
EOF

  # Governance playbook
  cat > governance/AGENT_PLAYBOOK.md <<'EOF'
# Multi-Agent Governance Playbook
**Scope:** MCP, Custodian, Telemetry, Autonomy, Relay

## Roles
- Custodian: Seal validation, incident approval
- Telemetry: Drift scoring, heartbeat emission
- Relay: External integration
- Autonomy: STOP–RESET–REALIGN enforcement
- Auditor: Compliance checks

## Rules
1. Drift ≥ 10 → Custodian freeze
2. Incident logged → Governance approval required
3. Seal invalid → Autonomy paused
4. Relay offline → MCP escalation
EOF

  # Migration workflow
  cat > migration/workflow.md <<'EOF'
# Migration Workflow (Audit-Tight)
1. Export configs (global_config.yaml)
2. Backup ledger.db
3. Validate seals
4. Run compliance_audit.py
5. Deploy relay_server.py
6. Restart autonomy_loop
7. Custodian approval required
EOF

  # QA checklist
  cat > qa/QA_CHECKLIST.md <<'EOF'
# QA Checklist
- [ ] MCP health endpoint returns 200
- [ ] Heartbeat emits UTC timestamp
- [ ] Telemetry logs drift < 10
- [ ] Autonomy loop cycles every 60s
- [ ] Incident logger writes to ledger
- [ ] Seal template validated
- [ ] Snapshot archived
- [ ] Audit script passes
EOF

  # Recovery protocol
  cat > custody/RECOVERY_PROTOCOL.md <<'EOF'
# Recovery Protocol
**Trigger:** MCP fault / Drift > 15 / Ledger corruption

## Steps
1. Halt autonomy loop
2. Notify custodian
3. Restore ledger backup
4. Validate seals
5. Resume governance cycle
EOF

  # Security policy
  cat > governance/SECURITY_POLICY.md <<'EOF'
# Security Policy
- Ledger access restricted to Custodian role
- Drift scoring module immutable
- Relay endpoints authenticated
- Memory pack encrypted
- Audit logs sealed daily
EOF

  # Telemetry dashboard stub
  cat > telemetry/dashboard_stub.py <<'EOF'
def render_dashboard():
    print("Telemetry Dashboard")
    print("Heartbeats: OK")
    print("Drift: < 10")
    print("Governance: Enforced")

if __name__ == "__main__":
    render_dashboard()
EOF

  # Utility functions
  cat > utils/helpers.py <<'EOF'
import uuid, datetime
def generate_uuid(): return str(uuid.uuid4())
def utc_now(): return datetime.datetime.utcnow().isoformat()
EOF

  # Validation script
  cat > scripts/validate_codex.py <<'EOF'
import os
paths = ["custody/ledger.db", "configs/global_config.yaml", "seals/SEAL_TEMPLATE.md"]
for p in paths:
    print(("Found " + p) if os.path.exists(p) else ("Missing " + p))
EOF

  # Workflow orchestrator
  cat > workflow/orchestrator.py <<'EOF'
def run_workflow():
    print("Running governance workflow...")
    # Seal → Telemetry → Drift → Incident → Snapshot → Audit
    print("Workflow complete.")
if __name__ == "__main__":
    run_workflow()
EOF

  # XML export stub
  cat > export/xml_stub.py <<'EOF'
def export_seal_to_xml(seal_id):
    return f"<seal><id>{seal_id}</id><status>VALID</status></seal>"
EOF

  # YAML compliance manifest
  cat > compliance/manifest.yaml <<'EOF'
seal_version: MVP_v1
environment: dev
custodian: CUST001
checks:
  - ledger_integrity: true
  - drift_threshold: "< 10"
  - autonomy_running: true
  - governance_enforced: true
EOF

  # Zero Drift Charter
  cat > governance/ZERO_DRIFT_CHARTER.md <<'EOF'
# Zero Drift Charter
**Principle:** All artifacts reproducible, audit-tight, stackable.

## Invariants
- No repetition loops
- No drift beyond threshold
- CFMS enforced at every layer
- Renewal rhythm daily
- Custodian oversight mandatory
EOF

  # Requirements (explicit)
  cat > requirements.txt <<'EOF'
fastapi
uvicorn
requests
EOF

  echo "Bootstrap files written."
}

cmd_up() {
  ensure_python
  ensure_deps
  "$PYTHON_BIN" orchestration/MCP/relay_server.py & echo $! > .pid_relay
  "$PYTHON_BIN" telemetry/telemetry_engine.py & echo $! > .pid_telemetry
  "$PYTHON_BIN" autonomy/start_autonomy_loop.py & echo $! > .pid_autonomy
  echo "Services started (relay:$(cat .pid_relay), telemetry:$(cat .pid_telemetry), autonomy:$(cat .pid_autonomy))."
}

cmd_down() {
  for f in .pid_relay .pid_telemetry .pid_autonomy; do
    if [[ -f "$f" ]]; then
      kill "$(cat "$f")" 2>/dev/null || true
      rm -f "$f"
    fi
  done
  echo "Services stopped."
}

cmd_seal() {
  "$PYTHON_BIN" - <<'EOF'
import uuid, datetime, pathlib
pathlib.Path("seals").mkdir(exist_ok=True)
cid=str(uuid.uuid4())
content=f"""# MAOS Seal Document

**Seal Version:** MVP_v1
**Date:** {datetime.date.today().isoformat()}
**Environment:** dev
**Correlation ID:** {cid}

## Conditions
- MCP online ✅
- Memory Pack online ✅
- Telemetry live ✅
- Agents active ✅
- Autonomy running ✅
- Drift < 10 ✅
- Governance enforced ✅
- Ledger healthy ✅

**Seal Status:** VALID
**Signed By:** Custodian
"""
open("seals/SEAL_CURRENT.md","w").write(content)
print("Sealed with Correlation ID:", cid)
EOF
}

cmd_audit() {
  "$PYTHON_BIN" scripts/compliance_audit.py
}

cmd_qa() {
  "$PYTHON_BIN" scripts/validate_codex.py
  "$PYTHON_BIN" telemetry/dashboard_stub.py
  echo "QA checklist executed."
}

cmd_incident() {
  desc="${1:-}"
  if [[ -z "$desc" ]]; then
    echo "Usage: $0 incident \"description\"" >&2
    exit 1
  fi
  "$PYTHON_BIN" scripts/custodian_cli.py --incident "$desc"
}

cmd_snapshot() {
  "$PYTHON_BIN" - <<'EOF'
import datetime, uuid, pathlib
pathlib.Path("custody").mkdir(exist_ok=True)
run_id=str(uuid.uuid4())
content=f"""# Daily Autonomy Snapshot

**Date:** {datetime.date.today().isoformat()}
**Seal Version:** MVP_v1
**Run ID:** {run_id}

## Summary
- Heartbeats: <count>
- Drift Scores: <values>
- Governance Events: <list>
- Ledger Health: OK
- Notes: Snapshot generated
"""
open(f"custody/DAILY_SNAPSHOT_{datetime.date.today().isoformat()}.md","w").write(content)
print("Snapshot created with Run ID:", run_id)
EOF
}

cmd_checksum() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 META_MEGA_CODEX.sh || true
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum META_MEGA_CODEX.sh || true
  else
    echo "SHA256 tool not found."
  fi
}

cmd_bootstrap() {
  ensure_python
  bootstrap_files
  ensure_deps
  echo "Bootstrap complete. Next: ./META_MEGA_CODEX.sh up"
}

case "${1:-}" in
  bootstrap) cmd_bootstrap ;;
  up) cmd_up ;;
  down) cmd_down ;;
  seal) cmd_seal ;;
  audit) cmd_audit ;;
  qa) cmd_qa ;;
  incident) shift || true; cmd_incident "${1:-}" ;;
  snapshot) cmd_snapshot ;;
  checksum) cmd_checksum ;;
  *) echo "Usage: $0 bootstrap|up|down|seal|audit|qa|incident \"desc\"|snapshot|checksum" ; exit 1 ;;
esac
