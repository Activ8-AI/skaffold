# Codex Runtime — Meta Mega Codex

Meta Mega Codex is a self-contained runtime that keeps CFMS invariants intact
while orchestrating persona-aware advisory agents. Everything lives inside this
directory so it can be dropped into any repository without touching the host
project.

## Directory layout

- `codex_executor.py` — materializes agent outputs into normalized JSON.
- `codex_relay.py` — resolves persona/role routing and invokes the executor.
- `codex_logger.py` — records environment + git metadata per run.
- `codex_digest_report.py` — aggregates PreservationVault runs into digest files.
- `codex_evaluation.json` — normalized evaluation schema copied into each run.
- `run_and_log.sh` — helper to run the full pipeline end-to-end.
- `codex_gh_action.yml` — GitHub Action that wires the runtime into automation.
- `requirements.txt` — runtime dependencies (PyYAML only).
- `stacks/` — persona stacks plus shared `_cfms_invariants.yaml`.
- `config/` — policies and environment wiring.
- `PreservationVault/` — append-only vault for outputs, digests, evaluations.

## Quickstart

```bash
cd meta_mega_codex
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
mkdir -p PreservationVault
git init PreservationVault && git -C PreservationVault commit --allow-empty -m "Vault init"
./run_and_log.sh stacks/kim_watson_stack.yaml kim advisor
```

The `run_and_log.sh` script creates `PreservationVault/runs/<timestamp>` folders,
stores relay + executor artifacts, copies the evaluation schema, and commits the
vault so it can be pushed independently (see `codex_gh_action.yml` for CI wiring).

## Generating digests

```bash
python3 codex_digest_report.py --vault PreservationVault \
  --days 7 \
  --output PreservationVault/digests/weekly.json
```

The digest file captures all runs in the last _n_ days with their evaluation
criteria payloads so a weekly rollup can be sent to stakeholders.
