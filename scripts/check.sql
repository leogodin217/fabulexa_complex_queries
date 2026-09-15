-- Appended by check.sh / check.bat after `expected` (the tier's reference)
-- and `actual` (the candidate) exist as temp tables. Read-only otherwise.
-- Plain list output throughout: an empty result then prints nothing, so a
-- clean run is just the verdict line.
.mode list
.headers off
.separator '  '

-- Columns: name, type and position must all agree.
create temp table col_diff as
with e as (
    select row_number() over () as pos, column_name, column_type
    from (describe expected)
),
a as (
    select row_number() over () as pos, column_name, column_type
    from (describe actual)
)
select 'expected' as side, * from (from e except from a)
union all
select 'actual' as side, * from (from a except from e);

select '-- columns differ (side, position, name, type):'
where exists (from col_diff);
select side, pos, column_name, column_type
from col_diff
order by side desc, pos;

-- Rows: multiset equality, so duplicates count. Each row is compared as the
-- text of its struct, so a column mismatch above cannot abort this step.
create temp table row_diff as
with e as (select t::varchar as row from expected t),
     a as (select t::varchar as row from actual t)
select 'missing' as side, row from (from e except all from a)
union all
select 'extra' as side, row from (from a except all from e);

select '-- rows differ (first 20; missing = in the reference only, extra = in the candidate only):'
where exists (from row_diff);
select side, row from row_diff order by side desc, row limit 20;

select case
    when (select count(*) from col_diff) = 0
     and (select count(*) from row_diff) = 0
    then 'EQUAL'
    else 'DIFFERENT: '
         || (select count(*) from col_diff) || ' column difference(s), '
         || (select count(*) from row_diff where side = 'missing') || ' row(s) missing, '
         || (select count(*) from row_diff where side = 'extra') || ' row(s) extra'
end;
