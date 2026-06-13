#!/usr/bin/env bash
# Découpe APIDTOs.swift en fichiers par domaine (MARK sections).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT/myfidpass/Services/API"
SRC="$API_DIR/APIDTOs.swift"
python3 - "$SRC" "$API_DIR" << 'PY'
import re, sys
from pathlib import Path

src_path = Path(sys.argv[1])
out_dir = Path(sys.argv[2])
text = src_path.read_text()
lines = text.splitlines(keepends=True)

header = """//
//  Généré / maintenu par scripts/split-apidtos.swift — helpers de décodage partagés.
//

import Foundation

"""

helper_end = None
for i, line in enumerate(lines):
    if line.startswith("private func decodeFlexibleOptionalBool") or line.startswith("func decodeFlexibleOptionalBool"):
        helper_end = i
        break
    if line.startswith("// MARK:") and helper_end is None:
        # skip header comments before helper
        continue
for i, line in enumerate(lines):
    if line.startswith("// MARK:"):
        if helper_end is None:
            helper_end = i
        break

if helper_end is None:
    raise SystemExit("No MARK found")

helper_body = "".join(lines[:helper_end])
(out_dir / "APIDTOsDecoding.swift").write_text(header.replace("helpers de décodage partagés.", "Helpers de décodage partagés entre fichiers APIDTOs+*.") + helper_body)

sections = []
current_name = None
current_lines = []
for line in lines[helper_end:]:
    m = re.match(r"// MARK: - (.+)", line.strip())
    if m:
        if current_name:
            sections.append((current_name, current_lines))
        raw = m.group(1)
        safe = re.sub(r"[^A-Za-z0-9]+", "", raw.split("(")[0].split("/")[0])[:24] or "Section"
        current_name = f"{len(sections):02d}_{safe}"
        current_lines = [line]
    elif current_name:
        current_lines.append(line)
if current_name:
    sections.append((current_name, current_lines))

for name, body in sections:
    fname = f"APIDTOs+{name}.swift"
    content = f"""//
//  {fname}
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

""" + "".join(body)
    (out_dir / fname).write_text(content)

print(f"Wrote {len(sections)} section files + APIDTOsDecoding.swift")
PY
echo "Done. Review diffs; remove migrated content from APIDTOs.swift manually or re-run after backup."
