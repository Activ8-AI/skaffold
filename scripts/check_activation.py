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
