from pathlib import Path
import sys
import yaml

path = Path(sys.argv[1] if len(sys.argv) > 1 else "apis/asyncapi/payment-events.yaml")
doc = yaml.safe_load(path.read_text(encoding="utf-8"))

errors = []
version = str(doc.get("asyncapi", ""))
if not version.startswith("3."):
    errors.append("Missing/invalid AsyncAPI 3.x version.")
if "info" not in doc:
    errors.append("Missing info.")
if "channels" not in doc or not doc["channels"]:
    errors.append("Missing channels.")
if "operations" not in doc or not doc["operations"]:
    errors.append("Missing operations.")

if errors:
    for error in errors:
        print("ERROR:", error)
    raise SystemExit(1)

print(f"OK: {path} basic structure valid, AsyncAPI={version}, channels={len(doc['channels'])}, operations={len(doc['operations'])}")
