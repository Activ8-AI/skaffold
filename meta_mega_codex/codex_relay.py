#!/usr/bin/env python3
"""
codex_relay.py

Responsible for routing persona+role requests to the correct CFMS stack,
delegating execution, and returning a normalized relay payload.
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

import yaml

from codex_executor import execute_stack


class RelayError(RuntimeError):
    """Raised when stacks or invariants cannot be resolved."""


def load_yaml(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise RelayError(f"Expected mapping data in {path}")
    return data


def deep_merge(base: Dict[str, Any], overlay: Dict[str, Any]) -> Dict[str, Any]:
    result: Dict[str, Any] = dict(base)
    for key, value in overlay.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def resolve_stack(
    persona: str,
    role: str,
    stacks_dir: Path,
    stack_path: Optional[Path],
) -> Dict[str, Any]:
    candidate_paths: List[Path]
    if stack_path:
        candidate_paths = [stack_path]
    else:
        candidate_paths = sorted(stacks_dir.glob("*.yaml"))

    for path in candidate_paths:
        stack = load_yaml(path)
        if stack.get("routing", {}).get("persona") != persona:
            continue
        if stack.get("routing", {}).get("role") != role:
            continue
        include_files = stack.get("include", [])
        merged = {}
        for include_file in include_files:
            include_path = stacks_dir / include_file
            merged = deep_merge(merged, load_yaml(include_path))
        resolved = deep_merge(merged, stack)
        resolved["_source_path"] = path.as_posix()
        return resolved

    raise RelayError(f"No stack routes persona={persona} role={role}")


def check_invariants(stack: Dict[str, Any]) -> Dict[str, Any]:
    invariants = stack.get("cfms_invariants")
    if not invariants:
        raise RelayError("Stack must include CFMS invariants via include directive.")

    compliance = {}
    for key, data in invariants.items():
        enforcement = data.get("enforcement", [])
        compliance[key] = {
            "pass": bool(enforcement),
            "rules": enforcement,
        }
    return compliance


def parse_payload(payload_str: str) -> Dict[str, Any]:
    payload_str = payload_str or "{}"
    try:
        parsed = json.loads(payload_str)
    except json.JSONDecodeError as exc:
        raise RelayError(f"Invalid payload JSON: {exc}") from exc

    if parsed is None:
        return {}
    if not isinstance(parsed, dict):
        raise RelayError("Payload must be a JSON object for normalization.")
    return parsed


def write_resolved_stack(stack: Dict[str, Any], destination: Path) -> None:
    destination.write_text(yaml.safe_dump(stack, sort_keys=False), encoding="utf-8")


def relay(args: argparse.Namespace) -> Dict[str, Any]:
    stacks_dir = Path(args.stacks_dir).resolve()
    run_dir = Path(args.run_dir).resolve()
    run_dir.mkdir(parents=True, exist_ok=True)
    stack_path = Path(args.stack_path).resolve() if args.stack_path else None
    stack = resolve_stack(args.persona, args.role, stacks_dir, stack_path)
    compliance = check_invariants(stack)
    payload = parse_payload(args.payload)

    write_resolved_stack(stack, run_dir / "stack_resolved.yaml")

    execution_summary = execute_stack(
        stack_config=stack,
        persona=args.persona,
        role=args.role,
        payload=payload,
        run_dir=run_dir,
    )

    return {
        "persona": args.persona,
        "role": args.role,
        "stack_id": stack.get("meta", {}).get("id"),
        "stack_source": stack.get("_source_path"),
        "compliance": compliance,
        "execution": execution_summary,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Meta Mega Codex relay")
    parser.add_argument("--persona", required=True)
    parser.add_argument("--role", required=True)
    parser.add_argument("--payload", default="{}")
    parser.add_argument("--stacks-dir", default="stacks")
    parser.add_argument("--stack-path", help="Optional explicit stack path")
    parser.add_argument("--run-dir", required=True)
    return parser.parse_args(argv)


def main() -> None:
    args = parse_args()
    result = relay(args)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
