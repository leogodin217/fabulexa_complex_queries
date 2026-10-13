#!/usr/bin/env bash
# Download the saas-billing warehouse (a DuckDB file) into this directory.
# Needs: curl, sha256sum. Re-running is a no-op when the file already verifies.
set -euo pipefail
cd "$(dirname "$0")"

TAG=saas-billing-v3
ASSET=saas-billing.duckdb
SHA256=f162d1b44b650d5095d51c7c2406ed104effeb561cd9f8fb08fa7159a1b84d0b
URL="https://github.com/leogodin217/fabulexa_complex_queries/releases/download/$TAG/$ASSET"
OUT=warehouse.duckdb

if [ -f "$OUT" ] && echo "$SHA256  $OUT" | sha256sum -c --status; then
  echo "$OUT already present and verified"
  exit 0
fi

echo "downloading $URL"
curl -L --fail --progress-bar -o "$OUT.part" "$URL"
echo "$SHA256  $OUT.part" | sha256sum -c --status || {
  rm -f "$OUT.part"
  echo "sha256 mismatch — download discarded" >&2
  exit 1
}
mv "$OUT.part" "$OUT"
echo "ok: $OUT"
