#!/usr/bin/env bash
# Supprime tous les simulateurs iOS/watchOS et les images runtime associées.
# N’affecte pas un iPhone physique branché (Run Destination « iPhone … »).
# Prérequis : Xcode installé dans /Applications/Xcode.app
set -euo pipefail

if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
else
  echo "Erreur : Xcode introuvable dans /Applications/Xcode.app" >&2
  exit 1
fi

echo "[1/4] Arrêt des simulateurs…"
xcrun simctl shutdown all 2>/dev/null || true

echo "[2/4] Suppression de tous les appareils simulateurs…"
xcrun simctl delete all

echo "[3/4] Suppression de toutes les images runtime (libère plusieurs Go)…"
xcrun simctl runtime delete all

echo "[4/4] Caches CoreSimulator…"
rm -rf "$HOME/Library/Developer/CoreSimulator/Caches" \
       "$HOME/Library/Developer/CoreSimulator/Temp" 2>/dev/null || true

echo "Terminé. Liste des runtimes :"
xcrun simctl runtime list
echo ""
echo "Pour réinstaller un simulateur plus tard : Xcode > Settings > Platforms (ou téléchargement au premier lancement)."
