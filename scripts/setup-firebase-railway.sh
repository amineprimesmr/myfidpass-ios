#!/usr/bin/env bash
# Configure FIREBASE_SERVICE_ACCOUNT_JSON on Railway pour les push Android (FCM).
# Usage :
#   1. Firebase Console → myfidpass-mobile → Paramètres → Comptes de service → Générer une nouvelle clé privée
#   2. ./scripts/setup-firebase-railway.sh ~/Downloads/myfidpass-mobile-firebase-adminsdk-xxxxx.json
set -euo pipefail

KEY_FILE="${1:-}"
if [[ -z "$KEY_FILE" || ! -f "$KEY_FILE" ]]; then
  echo "Usage: $0 /chemin/vers/service-account.json"
  echo "Console : https://console.firebase.google.com/project/myfidpass-mobile/settings/serviceaccounts/adminsdk"
  exit 1
fi

if ! command -v railway >/dev/null 2>&1; then
  echo "Railway CLI requis : npm i -g @railway/cli && railway login"
  exit 1
fi

JSON_ONELINE="$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))' "$KEY_FILE")"
railway variables set "FIREBASE_SERVICE_ACCOUNT_JSON=$JSON_ONELINE"
echo "✓ FIREBASE_SERVICE_ACCOUNT_JSON défini sur Railway (projet lié au cwd fidelity)"
