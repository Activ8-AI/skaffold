import os, random

def calculate_drift():
    # If DRIFT_FIXED is set, use deterministic drift; otherwise bounded random.
    fixed = os.environ.get("DRIFT_FIXED")
    if fixed is not None:
        try:
            drift = int(fixed)
        except ValueError:
            drift = 5
    else:
        random.seed(42)  # zero drift seed for reproducibility
        drift = random.randint(0, 15)
    status = "green" if drift < 10 else "red"
    return {"drift": drift, "status": status}
