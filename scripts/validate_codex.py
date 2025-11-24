import os
paths = ["custody/ledger.db", "configs/global_config.yaml", "seals/SEAL_TEMPLATE.md"]
for p in paths:
    print(("Found " + p) if os.path.exists(p) else ("Missing " + p))
