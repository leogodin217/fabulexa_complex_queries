-- pack_diff: compare two packs (views or tables) as multisets of rows.
-- Usage, inside any duckdb session on the warehouse:
--
--     .read exercises/nhs/check.sql
--     create temp view expected as <the reference or solution select>;
--     create temp view actual   as <your select>;
--     select * from pack_diff('expected', 'actual');
--
-- Empty result = the packs are equal. Otherwise each differing row comes
-- back once per occurrence (duplicates count), tagged:
--   missing    — in the expected pack only (your pack lost or changed it)
--   unexpected — in your pack only
-- Each row is compared as the text of its struct, so the two sides may be
-- compared even while their column lists disagree; a changed column name or
-- type shows up as every row differing.
-- scripts/check-pack.sh wraps this file end to end and prints a verdict.
create or replace temp macro pack_diff(expected, actual) as table
with
    e as (select t::varchar as row from query_table(expected) as t),
    a as (select t::varchar as row from query_table(actual) as t)
select 'missing' as side, row
from (from e except all from a)
union all
select 'unexpected' as side, row
from (from a except all from e)
