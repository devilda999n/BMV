#!/usr/bin/env bash
set -e

python3 - <<'PY'
from pathlib import Path
import re

p = Path("app/src/main/res/values/static_strings.xml")
s = p.read_text()

s = re.sub(
    r'(<string\s+name="app_name"[^>]*>).*?(</string>)',
    r'\1Ashish\2',
    s,
    count=1
)

s = re.sub(
    r'(<string\s+name="firefox"[^>]*>).*?(</string>)',
    r'\1Ashish\2',
    s,
    count=1
)

p.write_text(s)
PY

echo "Ashish customization complete"
