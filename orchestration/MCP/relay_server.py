from fastapi import FastAPI
import uvicorn, datetime

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.datetime.utcnow().isoformat()}

@app.get("/heartbeat")
def heartbeat():
    return {"heartbeat": "alive", "utc": datetime.datetime.utcnow().isoformat()}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
