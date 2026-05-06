#!/usr/bin/env bash
# =============================================================================
# cursor-repo-mega-cleanup.sh — Nettoyage A→Z pour le dépôt myfidpass + caches
#   Cursor / Xcode liés au projet (sans toucher au code source ni à .git).
#
# Usage:
#   ./scripts/cursor-repo-mega-cleanup.sh                 # dépôt + caches Cursor légers
#   ./scripts/cursor-repo-mega-cleanup.sh --cursor-nuclear  # + reset complet Cursor (conversations, workspaces, transcripts…)
#   ./scripts/cursor-repo-mega-cleanup.sh --dry-run
#   ./scripts/cursor-repo-mega-cleanup.sh --with-mac      # enchaîne mac-ultra-cleanup.sh
#   ./scripts/cursor-repo-mega-cleanup.sh --help
#
# Fermez Xcode / Cursor / Android Studio avant d'exécuter.
# Ne modifie pas project.pbxproj ni les sources Swift/Kotlin.
# =============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=0
WITH_MAC=0
CURSOR_NUCLEAR=0

log()  { echo -e "${BLUE}[mega]${NC} $*"; }
ok()   { echo -e "${GREEN}[ok]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*" >&2; }

usage() {
  sed -n '2,22p' "$0" | sed 's/^# //g; s/^#//g'
  exit 0
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --with-mac) WITH_MAC=1 ;;
    --cursor-nuclear) CURSOR_NUCLEAR=1 ;;
    -h|--help) usage ;;
    *) warn "argument inconnu ignoré: $arg" ;;
  esac
done

rm_path() {
  local p="$1"
  [[ -e "$p" ]] || return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "[dry-run] supprimerait: $p"
    return 0
  fi
  chmod -R u+w "$p" 2>/dev/null || true
  local i
  for i in 1 2 3; do
    if rm -rf "$p" 2>/dev/null; then
      ok "supprimé: $p"
      return 0
    fi
    sleep 0.4
  done
  err "échec (fermez Xcode / simulateur puis relancez): $p"
}

empty_dir_top() {
  local d="$1"
  [[ -d "$d" ]] || return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "[dry-run] viderait: $d"
    return 0
  fi
  chmod -R u+w "$d" 2>/dev/null || true
  find "$d" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
  ok "vidé: $d"
}

quit_cursor_app() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "[dry-run] quitterait Cursor s'il est ouvert"
    return 0
  fi
  if ! pgrep -x Cursor >/dev/null 2>&1 && ! pgrep -f "Cursor.app/Contents/MacOS/Cursor" >/dev/null 2>&1; then
    return 0
  fi
  log "Fermeture de Cursor (obligatoire pour supprimer state.vscdb / conversations)…"
  osascript -e 'tell application "Cursor" to quit' 2>/dev/null || true
  sleep 2
  killall Cursor 2>/dev/null || true
  sleep 1
}

# Reset « usine » côté Cursor : conversations (state.vscdb), workspaces, agent transcripts, plans.
# Conserve : User/settings.json, User/keybindings.json, User/snippets, ~/.cursor/extensions, ~/.cursor/plugins, ~/.cursor/skills-cursor, argv.json
cursor_nuclear_reset() {
  local BASE="$HOME/Library/Application Support/Cursor"
  quit_cursor_app

  log "Cursor NUCLEAR — conversations & état IA (globalStorage state.vscdb…)"
  if [[ -d "$BASE/User/globalStorage" ]]; then
    empty_dir_top "$BASE/User/globalStorage"
  fi

  log "Cursor NUCLEAR — workspaceStorage (état par projet / fenêtres)"
  [[ -d "$BASE/User/workspaceStorage" ]] && empty_dir_top "$BASE/User/workspaceStorage"

  log "Cursor NUCLEAR — History (historique local d’édition)"
  [[ -d "$BASE/User/History" ]] && empty_dir_top "$BASE/User/History"

  log "Cursor NUCLEAR — stockage web intégré (IndexedDB, sessions…)"
  for sub in "Session Storage" "Local Storage" IndexedDB Partitions WebStorage "Service Worker" blob_storage Workspaces glassMultiRootWorkspaces; do
    rm_path "$BASE/$sub"
  done
  rm_path "$BASE/Cookies"
  rm_path "$BASE/Cookies-journal"

  log "Cursor NUCLEAR — caches racine (Dawn, configs cachées, snapshots…)"
  for sub in DawnGraphiteCache DawnWebGPUCache CachedConfigurations CachedProfilesData snapshots process-monitor sentry Backups; do
    rm_path "$BASE/$sub"
  done

  local DOT="$HOME/.cursor"
  if [[ -d "$DOT/projects" ]]; then
    log "Cursor NUCLEAR — dossiers projet Cursor (transcripts, assets session, MCP cache local…)"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      warn "[dry-run] viderait agent-transcripts, agent-tools, assets, canvases, mcps, terminals sous $DOT/projects/*"
    else
      find "$DOT/projects" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r proj; do
        for sub in agent-transcripts agent-tools assets canvases mcps terminals; do
          if [[ -d "$proj/$sub" ]]; then
            empty_dir_top "$proj/$sub"
          fi
        done
        true
      done
      ok "projets ~/.cursor/projects nettoyés (arborescence conservée)"
    fi
  fi
  rm_path "$DOT/plans"
  rm_path "$DOT/ai-tracking"
  rm_path "$DOT/ide_state.json"
  empty_dir_top "$HOME/.cursor/browser-logs"
}

echo ""
log "Racine dépôt: $ROOT"
log "Mode: $([[ "$DRY_RUN" -eq 1 ]] && echo dry-run || echo application réelle)"
echo ""

# --- Artefacts Android (dossiers uniquement, pas de gradlew) ---
log "Android: dossiers de build / caches locaux au dépôt"
rm_path "$ROOT/android/.gradle"
rm_path "$ROOT/android/build"
rm_path "$ROOT/android/app/build"
rm_path "$ROOT/android/captures"
# caches IDE éventuels
rm_path "$ROOT/android/.idea/caches"
rm_path "$ROOT/android/.idea/libraries"

# --- Fichiers parasites macOS dans le dépôt ---
log "Fichiers .DS_Store dans le dépôt"
if [[ "$DRY_RUN" -eq 1 ]]; then
  warn "[dry-run] find . -name .DS_Store (aperçu max 40)"
  find "$ROOT" -name .DS_Store 2>/dev/null | head -40 || true
else
  find "$ROOT" -name .DS_Store -delete 2>/dev/null || true
  ok ".DS_Store supprimés (best-effort)"
fi

# --- SwiftPM / build local si présents ---
log "SwiftPM / builds locaux (.build) sous le dépôt"
find "$ROOT" -type d -name .build -prune 2>/dev/null | while read -r b; do
  rm_path "$b"
done

# --- Xcode DerivedData : uniquement dossiers dont le nom évoque ce projet ---
log "Xcode DerivedData (ciblé myfidpass / MyFidpass uniquement)"
XCODE_DD="$HOME/Library/Developer/Xcode/DerivedData"
if [[ -d "$XCODE_DD" ]]; then
  while IFS= read -r -d '' d; do
    rm_path "$d"
  done < <(find "$XCODE_DD" -maxdepth 1 -type d \( \
    -iname '*myfidpass*' -o -iname '*MyFidpass*' \
  \) -print0 2>/dev/null || true)
else
  warn "DerivedData absent ou inaccessible: $XCODE_DD"
fi

# --- Caches Xcode « légers » liés aux builds (re-téléchargeable) ---
log "Caches Xcode / SwiftPM utilisateur (pas les prefs Xcode)"
for x in \
  "$HOME/Library/Caches/com.apple.dt.Xcode" \
  "$HOME/Library/Caches/org.swift.swiftpm"; do
  rm_path "$x"
done

# --- Cursor : caches applicatifs + option reset complet (conversations, etc.) ---
CURSOR_BASE="$HOME/Library/Application Support/Cursor"
if [[ "$CURSOR_NUCLEAR" -eq 1 ]]; then
  cursor_nuclear_reset
fi

log "Cursor: Cache, CachedData, logs applicatifs"
for sub in Cache CachedData "Code Cache" GPUCache DawnCache logs; do
  rm_path "$CURSOR_BASE/$sub"
done
rm_path "$HOME/.cursor/cache"

# --- Cache navigateur Cursor (profils agent) si présent ---
BROWSER_LOGS="$HOME/.cursor/browser-logs"
if [[ -d "$BROWSER_LOGS" ]] && [[ "$CURSOR_NUCLEAR" -eq 0 ]]; then
  log "Cursor browser-logs"
  empty_dir_top "$BROWSER_LOGS"
fi

# --- Optionnel : nettoyage mac complet (Homebrew, DerivedData entier, etc.) ---
if [[ "$WITH_MAC" -eq 1 ]]; then
  MAC_SCRIPT="$ROOT/scripts/mac-ultra-cleanup.sh"
  if [[ -x "$MAC_SCRIPT" ]] || [[ -f "$MAC_SCRIPT" ]]; then
    log "Enchaînement: $MAC_SCRIPT $([[ "$DRY_RUN" -eq 1 ]] && echo --dry-run)"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      bash "$MAC_SCRIPT" --dry-run || warn "mac-ultra-cleanup dry-run a retourné une erreur (ignorée)"
    else
      bash "$MAC_SCRIPT" || warn "mac-ultra-cleanup a retourné une erreur partielle (voir ci-dessus)"
    fi
  else
    err "Script introuvable: $MAC_SCRIPT"
  fi
fi

echo ""
ok "Mega nettoyage dépôt + Cursor + caches Xcode ciblés terminé."
if [[ "$DRY_RUN" -eq 1 ]]; then
  warn "Dry-run: relancez sans --dry-run pour appliquer."
fi
if [[ "$WITH_MAC" -eq 0 ]]; then
  warn "Astuce: --with-mac enchaîne scripts/mac-ultra-cleanup.sh (DerivedData global, Corbeille, Docker, etc.)."
fi
if [[ "$CURSOR_NUCLEAR" -eq 0 ]]; then
  warn "Pour effacer conversations + état Composer Cursor: --cursor-nuclear (ferme Cursor automatiquement)."
fi
echo ""
exit 0
