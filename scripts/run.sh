#!/usr/bin/env bash
# Run one query file against a dataset's warehouse and print the result.
#   scripts/run.sh <dataset> <query.sql>            # table on stdout
#   scripts/run.sh <dataset> <query.sql> out.csv    # CSV to a file
# Needs: the duckdb CLI on PATH; datasets/<dataset>/setup.sh run once.
set -euo pipefail
cd "$(dirname "$0")/.."
dataset=$1; query=$2; out=${3:-}
db="datasets/$dataset/warehouse.duckdb"
[ -f "$db" ] || { echo "no $db — run datasets/$dataset/setup.sh first" >&2; exit 1; }
if [ -n "$out" ]; then
  duckdb -readonly -csv "$db" < "$query" > "$out"
  echo "wrote $out"
else
  duckdb -readonly "$db" < "$query"
fi
