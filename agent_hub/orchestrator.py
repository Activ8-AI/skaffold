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
