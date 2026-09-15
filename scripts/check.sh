#!/usr/bin/env bash
# Grade a query against a tier's reference: same columns (name, type, order)
# and the same multiset of rows.
#   scripts/check.sh <dataset> <tier> <candidate.sql>
# Prints any column differences, up to 20 differing rows, and a final
# EQUAL / DIFFERENT line; exits 0 only on EQUAL.
# Needs: the duckdb CLI on PATH; datasets/<dataset>/setup.sh run once.
set -euo pipefail
cd "$(dirname "$0")/.."
dataset=$1; tier=$2; candidate=$3
db="datasets/$dataset/warehouse.duckdb"
reference="exercises/$dataset/$tier/reference.sql"
[ -f "$db" ] || { echo "no $db — run datasets/$dataset/setup.sh first" >&2; exit 1; }
[ -f "$reference" ] || { echo "no such tier: $reference" >&2; exit 1; }
[ -f "$candidate" ] || { echo "no such file: $candidate" >&2; exit 1; }

output=$(
  {
    echo "create temp table expected as"; cat "$reference"; echo ";"
    echo "create temp table actual as";   cat "$candidate"; echo ";"
    cat scripts/check.sql
  } | duckdb -readonly "$db"
)
printf '%s\n' "$output"
grep -q '^EQUAL' <<< "$output"
