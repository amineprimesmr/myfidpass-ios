#!/usr/bin/env bash
# Quitte Cursor puis lance le mega cleanup (à appeler avec nohup depuis l’extérieur).
set -euo pipefail
LOG="${CURSOR_CLEANUP_LOG:-/tmp/cursor-ultra-cleanup.log}"
exec >"$LOG" 2>&1
echo "=== $(date) — stop Cursor ==="
osascript -e 'tell application "Cursor" to quit' 2>/dev/null || true
sleep 2
killall Cursor 2>/dev/null || true
sleep 2
killall -9 Cursor 2>/dev/null || true
sleep 1
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "=== $(date) — mega cleanup ==="
exec bash "$ROOT/scripts/cursor-repo-mega-cleanup.sh" --cursor-nuclear --with-mac
