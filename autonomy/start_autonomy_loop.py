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
