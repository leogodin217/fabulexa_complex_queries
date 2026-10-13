#!/usr/bin/env bash
# Grade one pack query against another: the same multiset of rows, each row
# compared as the text of its struct (so column names/types/order matter).
#   scripts/check-pack.sh <dataset> <expected.sql> <candidate.sql>
# Both .sql files are bare SELECTs (no semicolon); they are wrapped as temp
# views and diffed with the pack_diff macro (exercises/<dataset>/check.sql).
# Prints up to 20 differing rows and a final EQUAL / DIFFERENT line; exits 0
# only on EQUAL.
# Needs: the duckdb CLI on PATH; datasets/<dataset>/setup.sh run once.
set -euo pipefail
cd "$(dirname "$0")/.."
dataset=$1; expected=$2; candidate=$3
db="datasets/$dataset/warehouse.duckdb"
macro="exercises/$dataset/check.sql"
[ -f "$db" ] || { echo "no $db — run datasets/$dataset/setup.sh first" >&2; exit 1; }
[ -f "$macro" ] || { echo "no $macro" >&2; exit 1; }
[ -f "$expected" ] || { echo "no such file: $expected" >&2; exit 1; }
[ -f "$candidate" ] || { echo "no such file: $candidate" >&2; exit 1; }

output=$(
  {
    cat "$macro"; echo ";"
    echo "create temp view expected as"; cat "$expected"; echo ";"
    echo "create temp view actual as";   cat "$candidate"; echo ";"
    cat <<'SQL'
.mode list
.headers off
.separator '  '
create temp table pack_row_diff as select * from pack_diff('expected', 'actual');
select '-- rows differ (first 20; missing = in the expected pack only, unexpected = in the candidate only):'
where exists (from pack_row_diff);
select side, row from pack_row_diff order by side desc, row limit 20;
select case
    when (select count(*) from pack_row_diff) = 0
    then 'EQUAL'
    else 'DIFFERENT: '
         || (select count(*) from pack_row_diff where side = 'missing') || ' row(s) missing, '
         || (select count(*) from pack_row_diff where side = 'unexpected') || ' row(s) unexpected'
end;
SQL
  } | duckdb -readonly "$db"
)
printf '%s\n' "$output"
grep -q '^EQUAL' <<< "$output"
