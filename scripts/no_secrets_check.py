from pathlib import Path
import re

patterns = [
    re.compile(r"(?i)(client_secret|password|api[_-]?key)\s*[:=]\s*['\"]?(?!CHANGE_ME|example|placeholder)([^\s'\"]+)"),
    re.compile(r"-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----"),
]

bad = []
for p in Path(".").rglob("*"):
    if not p.is_file() or ".git" in p.parts:
        continue
    if p.suffix.lower() in {".png",".jpg",".jpeg",".zip",".pdf"}:
        continue
    try:
        text = p.read_text(encoding="utf-8")
    except Exception:
        continue
    for pat in patterns:
        if pat.search(text):
            bad.append(str(p))
            break

if bad:
    print("Potential secrets:", *bad, sep="\n - ")
    raise SystemExit(1)
print("OK: no obvious secret pattern found.")
