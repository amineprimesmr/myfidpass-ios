#!/usr/bin/env bash
# Prépare l'AAB release et affiche le récap Play Console.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID="$ROOT/android"
AAB_SRC="$ANDROID/app/build/outputs/bundle/release/app-release.aab"
OUT_DIR="$ROOT/PlayStoreMetadata/releases"
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"

if [[ ! -f "$AAB_SRC" ]]; then
  echo "Build release…"
  (cd "$ANDROID" && ./gradlew :app:bundleRelease)
fi

mkdir -p "$OUT_DIR"
VERSION="$(grep versionName "$ANDROID/app/build.gradle.kts" | head -1 | sed 's/.*"\(.*\)".*/\1/')"
CODE="$(grep versionCode "$ANDROID/app/build.gradle.kts" | head -1 | sed 's/[^0-9]*//g')"
DEST="$OUT_DIR/myfidpass-${VERSION}-${CODE}.aab"
cp "$AAB_SRC" "$DEST"

echo ""
echo "✓ AAB prêt : $DEST"
echo "  Taille : $(du -h "$DEST" | cut -f1)"
echo ""
echo "Prochaine étape Play Console :"
echo "  Tester et publier → Tests → Tests internes → Créer une version → Uploader ce fichier"
echo ""
echo "Métadonnées : $ROOT/PlayStoreMetadata/CHECKLIST_PLAY.txt"
echo ""

if [[ -f "$ANDROID/keystore.properties" ]]; then
  STORE_PASS="$(grep storePassword "$ANDROID/keystore.properties" | cut -d= -f2-)"
  echo "SHA release (Firebase / OAuth Android) :"
  "$JAVA_HOME/bin/keytool" -list -v \
    -keystore "$ANDROID/keystore/myfidpass-upload.jks" \
    -alias upload -storepass "$STORE_PASS" 2>/dev/null \
    | grep -E "SHA 1:|SHA 256:" || true
fi
