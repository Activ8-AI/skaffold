#!/usr/bin/env python3
"""
codex_logger.py

Captures run metadata, environment fingerprints, and links them to stack
artifacts inside the PreservationVault.
"""
from __future__ import annotations

import argparse
import json
import platform
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional

import yaml


def read_yaml_if_exists(path: Path) -> Optional[Dict[str, Any]]:
    if not path.exists():
        return None
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def read_json_if_exists(path: Path) -> Optional[Dict[str, Any]]:
    if not path.exists():
        return None
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def git_command(args: list[str]) -> Optional[str]:
    try:
        output = subprocess.check_output(["git", *args], cwd=Path(__file__).parent, stderr=subprocess.DEVNULL)
        return output.decode("utf-8").strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def collect_environment(record_env: bool) -> Dict[str, Any]:
    data = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "platform": platform.platform(),
        "python_version": platform.python_version(),
    }
    if record_env:
        data["processor"] = platform.processor()
        data["machine"] = platform.machine()
    return data


def build_audit(run_dir: Path, record_env: bool) -> Dict[str, Any]:
    stack = read_yaml_if_exists(run_dir / "stack_resolved.yaml")
    relay = read_json_if_exists(run_dir / "relay.json")
    env = collect_environment(record_env)

    audit = {
        "run_dir": run_dir.as_posix(),
        "stack_id": stack.get("meta", {}).get("id") if stack else None,
        "relay_timestamp": relay.get("timestamp") if relay else None,
        "environment": env,
        "git": {
            "head": git_command(["rev-parse", "HEAD"]),
            "status_clean": git_command(["status", "--short"]) == "",
        },
    }
    return audit


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Meta Mega Codex logger")
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--record-env", action="store_true", default=False)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    run_dir = Path(args.run_dir).resolve()
    run_dir.mkdir(parents=True, exist_ok=True)
    audit = build_audit(run_dir, args.record_env)

    audit_path = run_dir / "audit.json"
    audit_path.write_text(json.dumps(audit, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
