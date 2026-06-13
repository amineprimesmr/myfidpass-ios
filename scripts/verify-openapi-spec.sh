#!/usr/bin/env bash
# Vérifie que la spec OpenAPI core est présente et valide (syntaxe YAML).
set -euo pipefail
SPEC="$(cd "$(dirname "$0")/.." && pwd)/Docs/openapi/myfidpass-core.yaml"
python3 - << PY
import sys
from pathlib import Path
p = Path("$SPEC")
text = p.read_text()
if "openapi:" not in text or "/api/auth/me" not in text:
    sys.exit("Spec OpenAPI incomplète")
print("OK:", p)
PY
