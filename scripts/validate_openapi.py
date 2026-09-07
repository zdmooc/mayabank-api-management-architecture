from pathlib import Path
import sys, yaml

path = Path(sys.argv[1] if len(sys.argv) > 1 else "apis/openapi/payment-api.yaml")
doc = yaml.safe_load(path.read_text(encoding="utf-8"))

errors = []
if not str(doc.get("openapi", "")).startswith("3."):
    errors.append("Missing/invalid OpenAPI 3.x version.")
if "info" not in doc:
    errors.append("Missing info.")
if "paths" not in doc or not doc["paths"]:
    errors.append("Missing paths.")

if errors:
    for e in errors:
        print("ERROR:", e)
    raise SystemExit(1)

print(f"OK: {path} basic structure valid, OpenAPI={doc['openapi']}, paths={len(doc['paths'])}")
print("Note: use a full OpenAPI linter in CI for specification-level validation.")
