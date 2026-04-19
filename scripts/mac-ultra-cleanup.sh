#!/usr/bin/env bash
# =============================================================================
# mac-ultra-cleanup.sh — Nettoyage approfondi macOS (Xcode, Cursor, caches dev)
# Usage:
#   ./mac-ultra-cleanup.sh              # mode standard (sans sudo)
#   ./mac-ultra-cleanup.sh --dry-run    # affiche ce qui serait supprimé
#   ./mac-ultra-cleanup.sh --aggressive # + simulateurs iOS, logs système (sudo)
#   ./mac-ultra-cleanup.sh --help
#
# Important: fermez Xcode, Cursor et les simulateurs avant d'exécuter.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=0
AGGRESSIVE=0

log() { echo -e "${BLUE}[mac-cleanup]${NC} $*"; }
ok()  { echo -e "${GREEN}[ok]${NC} $*"; }
warn(){ echo -e "${YELLOW}[attention]${NC} $*"; }
err() { echo -e "${RED}[erreur]${NC} $*" >&2; }

usage() {
  sed -n '2,12p' "$0" | sed 's/^# //g; s/^#//g'
  exit 0
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --aggressive) AGGRESSIVE=1 ;;
    -h|--help) usage ;;
  esac
done

bytes_human() {
  local b="${1:-0}"
  if command -v numfmt &>/dev/null; then
    numfmt --to=iec-i --suffix=B "$b" 2>/dev/null || echo "$b octets"
  else
    echo "$b octets"
  fi
}

dir_size_bytes() {
  local d="$1"
  [[ -d "$d" ]] || { echo 0; return; }
  du -sk "$d" 2>/dev/null | awk '{print $1 * 1024}' || echo 0
}

rm_path() {
  local p="$1"
  if [[ ! -e "$p" ]]; then
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "[dry-run] supprimerait: $p"
    return 0
  fi
  rm -rf "$p" && ok "supprimé: $p" || err "échec: $p"
}

empty_dir_contents() {
  local d="$1"
  [[ -d "$d" ]] || return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "[dry-run] viderait le contenu de: $d"
    return 0
  fi
  find "$d" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
  ok "vidé: $d"
}

disk_free_gb() {
  df -g / 2>/dev/null | awk 'NR==2 {print $4}' || echo "?"
}

echo ""
log "=== Espace disque libre (/) avant: $(disk_free_gb) Go (colonne Avail de df -g) ==="
echo ""

# --- Homebrew ---
if command -v brew &>/dev/null; then
  log "Homebrew: nettoyage des caches et formules inutilisées"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "[dry-run] brew cleanup --prune=all && brew autoremove"
  else
    brew cleanup --prune=all 2>/dev/null || true
    brew autoremove 2>/dev/null || true
    ok "Homebrew nettoyé"
  fi
fi

# --- npm / yarn / pnpm ---
if command -v npm &>/dev/null; then
  log "npm: cache clean"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "[dry-run] npm cache clean --force"
  else
    npm cache clean --force 2>/dev/null || true
    ok "npm cache"
  fi
fi
if command -v yarn &>/dev/null; then
  log "yarn: cache clean"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "[dry-run] yarn cache clean"
  else
    yarn cache clean 2>/dev/null || true
    ok "yarn cache"
  fi
fi
if command -v pnpm &>/dev/null; then
  log "pnpm: store prune"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "[dry-run] pnpm store prune"
  else
    pnpm store prune 2>/dev/null || true
    ok "pnpm store"
  fi
fi

# --- pip ---
if command -v pip3 &>/dev/null; then
  log "pip: cache purge"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "[dry-run] pip3 cache purge"
  else
    pip3 cache purge 2>/dev/null || true
    ok "pip cache"
  fi
fi

# --- CocoaPods ---
if command -v pod &>/dev/null; then
  log "CocoaPods: cache clean --all"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "[dry-run] pod cache clean --all"
  else
    pod cache clean --all 2>/dev/null || true
    ok "CocoaPods cache"
  fi
fi

# --- Docker (si installé) ---
if command -v docker &>/dev/null; then
  log "Docker: prune (images/conteneurs inutilisés)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "[dry-run] docker system prune -af --volumes"
  else
    docker system prune -af --volumes 2>/dev/null || warn "Docker: impossible (daemon arrêté ?)"
    ok "Docker prune (si applicable)"
  fi
fi

# --- Xcode ---
XCODE_DERIVED="$HOME/Library/Developer/Xcode/DerivedData"
XCODE_ARCHIVES="$HOME/Library/Developer/Xcode/Archives"
XCODE_DEVICE_SUPPORT="$HOME/Library/Developer/Xcode/iOS DeviceSupport"

log "Xcode: DerivedData, Archives, DeviceSupport"
BEFORE_DD=$(dir_size_bytes "$XCODE_DERIVED")
rm_path "$XCODE_DERIVED"
[[ "$DRY_RUN" -eq 0 ]] && [[ -n "$BEFORE_DD" ]] && ok "DerivedData (~$(bytes_human "$BEFORE_DD")) libéré si présent"

BEFORE_AR=$(dir_size_bytes "$XCODE_ARCHIVES")
rm_path "$XCODE_ARCHIVES"
[[ "$DRY_RUN" -eq 0 ]] && [[ -n "$BEFORE_AR" ]] && ok "Archives (~$(bytes_human "$BEFORE_AR"))"

BEFORE_DS=$(dir_size_bytes "$XCODE_DEVICE_SUPPORT")
rm_path "$XCODE_DEVICE_SUPPORT"
[[ "$DRY_RUN" -eq 0 ]] && [[ -n "$BEFORE_DS" ]] && ok "iOS DeviceSupport (~$(bytes_human "$BEFORE_DS"))"

# Caches Xcode (sans tout ~/Library)
for x in \
  "$HOME/Library/Caches/com.apple.dt.Xcode" \
  "$HOME/Library/Caches/org.swift.swiftpm" \
  "$HOME/Library/org.swift.swiftpm"; do
  rm_path "$x"
done

# --- Simulateurs iOS (agressif) ---
if [[ "$AGGRESSIVE" -eq 1 ]]; then
  log "Mode agressif: tous les simulateurs + images runtime + caches CoreSimulator"
  CORE_SIM="$HOME/Library/Developer/CoreSimulator"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "[dry-run] xcrun simctl shutdown all; delete all; runtime delete all; + Caches/Temp CoreSimulator"
  else
    if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
      export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
      xcrun simctl shutdown all 2>/dev/null || true
      xcrun simctl delete all 2>/dev/null || true
      xcrun simctl runtime delete all 2>/dev/null || warn "runtime delete: échec ou Xcode incomplet"
      rm_path "$CORE_SIM/Caches"
      rm_path "$CORE_SIM/Temp"
      ok "Simulateurs: appareils + runtimes supprimés (iPhone physique inchangé)"
    else
      warn "Xcode absent de /Applications/Xcode.app — simulateurs non traités"
    fi
  fi
fi

# --- Cursor / VS Code (caches uniquement) ---
log "Cursor: caches applicatifs (pas vos paramètres ni extensions)"
CURSOR_BASE="$HOME/Library/Application Support/Cursor"
for sub in Cache CachedData "Code Cache" GPUCache DawnCache logs; do
  rm_path "$CURSOR_BASE/$sub"
done
# Anciens emplacements possibles
rm_path "$HOME/.cursor/cache"

# VS Code au cas où
VSCODE_BASE="$HOME/Library/Application Support/Code"
for sub in Cache CachedData "Code Cache" GPUCache; do
  rm_path "$VSCODE_BASE/$sub"
done

# --- Corbeille ---
log "Corbeille utilisateur"
if [[ "$DRY_RUN" -eq 1 ]]; then
  warn "[dry-run] viderait ~/.Trash"
else
  rm -rf "$HOME/.Trash/"* 2>/dev/null || true
  ok "Corbeille vidée"
fi

# --- Caches utilisateur volumineux (sélectif) ---
log "Caches Safari (réseau) — optionnel"
SAFARI_CACHE="$HOME/Library/Caches/com.apple.Safari"
if [[ "$AGGRESSIVE" -eq 1 ]]; then
  rm_path "$SAFARI_CACHE"
else
  warn "Ignoré (utilisez --aggressive pour vider le cache Safari)"
fi

# --- Spotlight / métadonnées (réindexation future) ---
if [[ "$AGGRESSIVE" -eq 1 ]] && [[ "$DRY_RUN" -eq 0 ]]; then
  log "Spotlight: désactivation temporaire de l’index sur / (puis réactivation)"
  if sudo -n true 2>/dev/null; then
    sudo mdutil -i off / 2>/dev/null || true
    sudo mdutil -E / 2>/dev/null || true
    sudo mdutil -i on / 2>/dev/null || true
    ok "Index Spotlight reconstruit (peut prendre du temps en arrière-plan)"
  else
    warn "Spotlight: sudo requis — exécutez: sudo mdutil -E /"
  fi
fi

# --- Purge mémoire (nécessite sudo sur certaines versions) ---
if [[ "$AGGRESSIVE" -eq 1 ]] && [[ "$DRY_RUN" -eq 0 ]]; then
  log "Tentative de purge des caches mémoire du noyau (peut aider après fermeture des apps lourdes)"
  if command -v purge &>/dev/null; then
    if sudo -n purge 2>/dev/null; then
      ok "purge exécuté"
    else
      warn "purge nécessite sudo interactif — fermez les apps et relancez: sudo purge"
    fi
  else
    warn "commande purge absente sur ce macOS — fermez les applications pour libérer la RAM"
  fi
fi

# --- Logs utilisateur (léger) ---
log "Logs ~/Library/Logs (fichiers .log/.asl anciens, mode agressif)"
if [[ "$AGGRESSIVE" -eq 1 ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "[dry-run] find ~/Library/Logs -type f -mtime +7 -delete"
  else
    find "$HOME/Library/Logs" -type f \( -name "*.log" -o -name "*.asl" \) -mtime +7 -delete 2>/dev/null || true
    ok "Logs utilisateur anciens"
  fi
fi

# --- Time Machine snapshots locaux (souvent gourmands en espace) ---
if [[ "$AGGRESSIVE" -eq 1 ]] && [[ "$DRY_RUN" -eq 0 ]]; then
  log "Time Machine: listage des snapshots locaux"
  if command -v tmutil &>/dev/null; then
    if sudo -n true 2>/dev/null; then
      sudo tmutil listlocalsnapshots / 2>/dev/null | tail -n +2 | while read -r line; do
        # thinlocalsnapshots peut libérer de l'espace
        true
      done
      sudo tmutil thinlocalsnapshots / 999999999999 4 2>/dev/null && ok "Snapshots locaux Time Machine élagués" || warn "tmutil thinlocalsnapshots: ignoré ou indisponible"
    else
      warn "Time Machine: sudo requis pour thinlocalsnapshots — voir: tmutil listlocalsnapshots /"
    fi
  fi
fi

echo ""
log "=== Espace disque libre (/) après: $(disk_free_gb) Go ==="
echo ""
ok "Terminé."
if [[ "$DRY_RUN" -eq 1 ]]; then
  warn "C'était un dry-run — aucun fichier supprimé. Relancez sans --dry-run pour appliquer."
fi
warn "Conseils: Réglages système > Général > Stockage — activer « Optimiser le stockage »; redémarrer le Mac après ce script; garder ~15–20 % de disque libre pour le swap et les mises à jour."

exit 0
