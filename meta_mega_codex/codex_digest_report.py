#!/usr/bin/env python3
"""
codex_digest_report.py

Scans PreservationVault runs and produces a digest that can be emailed or
attached to weekly status updates.
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional


def parse_run_timestamp(run_path: Path) -> Optional[datetime]:
    """
    Run directories follow YYYY-MM-DD/HHMMSS. We parse the parent dir and leaf
    to derive a UTC timestamp.
    """
    try:
        day_part = run_path.parent.name
        time_part = run_path.name
        combined = f"{day_part}/{time_part}"
        return datetime.strptime(combined, "%Y-%m-%d/%H%M%S").replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def load_json(path: Path) -> Optional[Dict[str, Any]]:
    if not path.exists():
        return None
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def collect_runs(vault_dir: Path, days: int) -> List[Dict[str, Any]]:
    since = datetime.now(timezone.utc) - timedelta(days=days)
    runs_dir = vault_dir / "runs"
    runs: List[Dict[str, Any]] = []
    for day_dir in sorted(runs_dir.glob("*")):
        if not day_dir.is_dir():
            continue
        for run_dir in sorted(day_dir.glob("*")):
            if not run_dir.is_dir():
                continue
            run_ts = parse_run_timestamp(run_dir)
            if run_ts is None or run_ts < since:
                continue
            relay = load_json(run_dir / "relay.json") or {}
            evaluation = load_json(run_dir / "evaluation.json") or {}
            runs.append(
                {
                    "run_dir": run_dir.relative_to(vault_dir).as_posix(),
                    "timestamp": run_ts.isoformat(),
                    "persona": relay.get("persona"),
                    "role": relay.get("role"),
                    "stack_id": relay.get("stack_id"),
                    "scores": evaluation.get("criteria"),
                }
            )
    return runs


def summarize(runs: List[Dict[str, Any]]) -> Dict[str, Any]:
    if not runs:
        return {"count": 0, "stacks": [], "personae": []}
    stacks = sorted({run.get("stack_id") for run in runs if run.get("stack_id")})
    personae = sorted({run.get("persona") for run in runs if run.get("persona")})
    return {"count": len(runs), "stacks": stacks, "personae": personae}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Produce a PreservationVault digest")
    parser.add_argument("--vault", default="PreservationVault")
    parser.add_argument("--days", type=int, default=7)
    parser.add_argument("--output", help="Optional path to write the digest JSON")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    vault_dir = Path(args.vault).resolve()
    runs = collect_runs(vault_dir, args.days)
    digest = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "scope_days": args.days,
        "run_count": len(runs),
        "summary": summarize(runs),
        "runs": runs,
    }

    if args.output:
        output_path = Path(args.output).resolve()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(digest, indent=2), encoding="utf-8")
    else:
        print(json.dumps(digest, indent=2))


if __name__ == "__main__":
    main()
