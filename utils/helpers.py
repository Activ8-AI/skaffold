import uuid, datetime
def generate_uuid(): return str(uuid.uuid4())
def utc_now(): return datetime.datetime.utcnow().isoformat()
