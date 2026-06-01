#!/usr/bin/env bash
# Vérifie que les URLs exigées par Apple (3.1.2) répondent en HTTP 200.
set -euo pipefail

check() {
  local url="$1"
  local code
  code=$(curl -sL -o /dev/null -w "%{http_code}" "$url")
  if [[ "$code" == "200" ]]; then
    echo "OK  $code  $url"
  else
    echo "FAIL $code  $url"
    return 1
  fi
}

fail=0
check "https://www.myfidpass.fr/cgu" || fail=1
check "https://www.myfidpass.fr/politique-confidentialite" || fail=1
check "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/" || fail=1

if [[ "$fail" -eq 0 ]]; then
  echo ""
  echo "Toutes les URLs légales sont accessibles (200)."
  exit 0
fi
echo ""
echo "Corrigez les URLs en échec avant resoumission App Store Connect."
exit 1
