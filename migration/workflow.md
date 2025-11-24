# Migration Workflow (Audit-Tight)
1. Export configs (global_config.yaml)
2. Backup ledger.db
3. Validate seals
4. Run compliance_audit.py
5. Deploy relay_server.py
6. Restart autonomy_loop
7. Custodian approval required
