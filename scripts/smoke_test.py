import os, requests

base = os.getenv("API_BASE_URL", "http://localhost:8080").rstrip("/")
r = requests.get(base + "/health", timeout=5)
print("GET /health", r.status_code, r.text[:200])
r.raise_for_status()
