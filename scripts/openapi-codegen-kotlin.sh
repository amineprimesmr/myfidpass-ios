#!/usr/bin/env bash
# Vérifie la spec OpenAPI et rappelle la commande de codegen Kotlin (openapi-generator).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "$ROOT/scripts/verify-openapi-spec.sh"
OUT="$ROOT/android/app/build/generated/openapi"
echo ""
echo "Pour générer les modèles Kotlin (openapi-generator-cli requis) :"
echo "  openapi-generator-cli generate \\"
echo "    -i $ROOT/Docs/openapi/myfidpass-core.yaml \\"
echo "    -g kotlin \\"
echo "    -o $OUT \\"
echo "    --additional-properties=serializationLibrary=kotlinx_serialization,packageName=fr.myfidpass.api.generated"
echo ""
echo "Puis migrer progressivement les DTOs manuels vers fr.myfidpass.api.generated."
