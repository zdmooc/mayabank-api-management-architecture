from pathlib import Path
import re

CREDENTIAL_ASSIGNMENT = re.compile(
    r"(?i)(client_secret|password|api[_-]?key)\s*[:=]\s*['\"]?([^\s'\"]+)"
)
PRIVATE_KEY = re.compile(r"-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----")

ALLOWED_LITERAL_PREFIXES = (
    "CHANGE_ME",
    "example",
    "placeholder",
)
RUNTIME_EXPRESSIONS = (
    "$(",
    "${",
    "$",
    "?set",
)

bad = []

for p in Path(".").rglob("*"):
    if not p.is_file() or ".git" in p.parts:
        continue
    if p.suffix.lower() in {".png", ".jpg", ".jpeg", ".zip", ".pdf"}:
        continue

    try:
        text = p.read_text(encoding="utf-8")
    except Exception:
        continue

    if PRIVATE_KEY.search(text):
        bad.append(f"{p}: private key material")
        continue

    for match in CREDENTIAL_ASSIGNMENT.finditer(text):
        value = match.group(2).strip().rstrip(",}])")
        if value.startswith(ALLOWED_LITERAL_PREFIXES):
            continue
        if value.startswith(RUNTIME_EXPRESSIONS):
            continue
        bad.append(f"{p}: fixed credential-like assignment")
        break

if bad:
    print("Potential secrets:", *bad, sep="\n - ")
    raise SystemExit(1)

print("OK: no obvious fixed credential or private-key pattern found.")
