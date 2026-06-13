#!/usr/bin/env bash
# Alerte si un fichier Kotlin dépasse la limite (dette monolithique).
set -euo pipefail
LIMIT="${1:-400}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)/android/app/src/main/java"
failed=0
while IFS= read -r f; do
  lines=$(wc -l < "$f" | tr -d ' ')
  if [ "$lines" -gt "$LIMIT" ]; then
    echo "WARN: $f ($lines lignes > $LIMIT)"
    failed=1
  fi
done < <(find "$ROOT" -name '*.kt')
exit $failed
