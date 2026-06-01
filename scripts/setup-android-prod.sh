#!/usr/bin/env bash
# Configuration release Android MyFidpass (keystore + google-services.json).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID="$ROOT/android"
KEYSTORE_DIR="$ANDROID/keystore"
KEYSTORE_FILE="$KEYSTORE_DIR/myfidpass-upload.jks"
PROPS="$ANDROID/keystore.properties"

mkdir -p "$KEYSTORE_DIR"

if [[ ! -f "$KEYSTORE_FILE" ]]; then
  STORE_PASS="${MYFIDPASS_KEYSTORE_PASSWORD:-MyFidpassUpload2026!}"
  KEY_PASS="${MYFIDPASS_KEY_PASSWORD:-$STORE_PASS}"
  keytool -genkey -v \
    -keystore "$KEYSTORE_FILE" \
    -alias upload \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -storepass "$STORE_PASS" \
    -keypass "$KEY_PASS" \
    -dname "CN=MyFidpass, OU=Mobile, O=MyFidpass, L=Paris, ST=IDF, C=FR"
  cat > "$PROPS" <<EOF
storeFile=keystore/myfidpass-upload.jks
storePassword=$STORE_PASS
keyAlias=upload
keyPassword=$KEY_PASS
EOF
  echo "✓ Keystore créé : $KEYSTORE_FILE"
  echo "✓ keystore.properties écrit (gitignored)"
else
  echo "• Keystore déjà présent : $KEYSTORE_FILE"
fi

if [[ -n "${FIREBASE_ANDROID_GOOGLE_SERVICES_JSON:-}" ]]; then
  printf '%s' "$FIREBASE_ANDROID_GOOGLE_SERVICES_JSON" > "$ANDROID/app/google-services.json"
  echo "✓ google-services.json écrit depuis FIREBASE_ANDROID_GOOGLE_SERVICES_JSON"
elif [[ -n "${1:-}" && -f "$1" ]]; then
  cp "$1" "$ANDROID/app/google-services.json"
  echo "✓ google-services.json copié depuis $1"
elif [[ -f "$ANDROID/app/google-services.json" ]]; then
  echo "• google-services.json déjà présent"
else
  echo ""
  echo "⚠ google-services.json manquant — FCM ne fonctionnera pas tant que vous n'avez pas :"
  echo "  1. Créé un projet Firebase avec apps Android fr.myfidpass et fr.myfidpass.debug"
  echo "  2. Copié le fichier : ./scripts/setup-android-prod.sh /chemin/vers/google-services.json"
  echo "     ou export FIREBASE_ANDROID_GOOGLE_SERVICES_JSON='...' && ./scripts/setup-android-prod.sh"
fi

echo ""
echo "Empreintes SHA (à enregistrer dans Firebase + Google Cloud OAuth Android) :"
keytool -list -v -keystore "$KEYSTORE_FILE" -alias upload -storepass "$(grep storePassword "$PROPS" | cut -d= -f2)" 2>/dev/null | grep -E "SHA1:|SHA256:" || true
if [[ -f "${HOME}/.android/debug.keystore" ]]; then
  echo "Debug keystore :"
  keytool -list -v -keystore "${HOME}/.android/debug.keystore" -alias androiddebugkey -storepass android -keypass android 2>/dev/null | grep -E "SHA1:|SHA256:" || true
fi

echo ""
echo "Build release signé :"
echo "  cd android && ./gradlew :app:bundleRelease"
