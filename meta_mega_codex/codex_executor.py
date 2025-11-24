#!/usr/bin/env python3
"""
codex_executor.py

Executes Meta Mega Codex stacks by materializing agent outputs into normalized
JSON artifacts. The executor is intentionally lightweight so it can run inside
Github Actions, cron jobs, or developer laptops without an external model
dependency.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List


class CodexExecutorError(RuntimeError):
    """Raised when stack validation fails or execution cannot proceed."""


@dataclass
class AgentSpec:
    """Lightweight view over an agent entry in the stack."""

    name: str
    model: str
    outputs: List[Dict[str, Any]]


class CodexExecutor:
    """Runs all agents defined in a stack and persists normalized outputs."""

    def __init__(
        self,
        stack_config: Dict[str, Any],
        persona: str,
        role: str,
        payload: Dict[str, Any],
        run_dir: Path,
    ) -> None:
        self.stack_config = stack_config
        self.persona = persona
        self.role = role
        self.payload = payload
        self.run_dir = run_dir
        self.outputs_dir = self.run_dir / "outputs"
        self.outputs_dir.mkdir(parents=True, exist_ok=True)
        self._agent_specs = [
            AgentSpec(
                name=agent.get("name"),
                model=agent.get("model"),
                outputs=agent.get("outputs", []),
            )
            for agent in stack_config.get("agents", [])
        ]
        self._validate_stack()

    def _validate_stack(self) -> None:
        if not self._agent_specs:
            raise CodexExecutorError("Stack must declare at least one agent.")

        for spec in self._agent_specs:
            if not spec.name or not spec.model:
                raise CodexExecutorError("Agent entries require name and model fields.")
            if not spec.outputs:
                raise CodexExecutorError(f"Agent {spec.name} must declare at least one output.")
            first = spec.outputs[0]
            if first.get("format") != "json" or not first.get("normalize", False):
                raise CodexExecutorError(
                    f"Agent {spec.name} must emit normalized JSON according to CFMS invariants."
                )

    def run(self) -> Dict[str, Any]:
        """Executes all agents and returns a summary dictionary."""
        execution_records = []

        for spec in self._agent_specs:
            content = self._render_response(spec)
            artifact = {
                "agent": spec.name,
                "model": spec.model,
                "persona": self.persona,
                "role": self.role,
                "content": content,
                "normalized": True,
                "generated_at": datetime.now(timezone.utc).isoformat(),
            }
            artifact_path = self.outputs_dir / f"{spec.name}.json"
            artifact_path.write_text(json.dumps(artifact, indent=2), encoding="utf-8")

            execution_records.append(
                {
                    "agent": spec.name,
                    "model": spec.model,
                    "output_path": artifact_path.as_posix(),
                }
            )

        return {
            "stack_id": self.stack_config.get("meta", {}).get("id"),
            "persona": self.persona,
            "role": self.role,
            "payload": self.payload,
            "executed_at": datetime.now(timezone.utc).isoformat(),
            "artifacts": execution_records,
        }

    def _render_response(self, spec: AgentSpec) -> Dict[str, Any]:
        """
        Produces a deterministic advisory record. Since we do not call an
        external LLM, we synthesize a structured response from the payload.
        """
        payload_summary = self._summarize_payload(self.payload)
        recommendations = [
            "Validate assumptions with the requesting team.",
            "Document actionable next steps in the PreservationVault run.",
            "Schedule a follow-up checkpoint aligned with CFMS governance.",
        ]

        return {
            "persona": self.persona,
            "role": self.role,
            "model": spec.model,
            "payload_summary": payload_summary,
            "recommendations": recommendations,
        }

    @staticmethod
    def _summarize_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
        if not payload:
            return {"size": 0, "keys": [], "note": "empty payload"}

        keys = sorted(payload.keys())
        preview = {k: payload[k] for k in keys[:3]}
        return {"size": len(payload), "keys": keys, "preview": preview}


def execute_stack(
    stack_config: Dict[str, Any],
    persona: str,
    role: str,
    payload: Dict[str, Any],
    run_dir: Path,
) -> Dict[str, Any]:
    """
    Convenience wrapper to keep the relay module lightweight. Returns the
    executor summary dictionary for further processing.
    """
    executor = CodexExecutor(
        stack_config=stack_config,
        persona=persona,
        role=role,
        payload=payload,
        run_dir=run_dir,
    )
    return executor.run()


__all__ = ["CodexExecutor", "CodexExecutorError", "execute_stack"]
