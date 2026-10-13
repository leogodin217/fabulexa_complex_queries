#!/usr/bin/env bash
# Download the nhs warehouse (a DuckDB file) into this directory.
# Needs: curl, sha256sum. Re-running is a no-op when the file already verifies.
set -euo pipefail
cd "$(dirname "$0")"

TAG=nhs-v1
ASSET=nhs.duckdb
SHA256=244439543ba97c2e435c61648d17217a5df7f02344912e8b780deedcb63274aa
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
