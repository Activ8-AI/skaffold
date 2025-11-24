import requests, datetime
def send_relay_message(endpoint, payload):
    r = requests.post(endpoint, json=payload, timeout=5)
    return {"status": r.status_code, "timestamp": datetime.datetime.utcnow().isoformat()}
