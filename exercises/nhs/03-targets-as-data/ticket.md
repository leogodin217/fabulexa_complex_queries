# PACK-103 — Targets should be data, not literals

**From:** Performance team
**Severity:** Normal
**Kind:** Change request (refactor; output must not move)

National targets change — the FDS target rises to 80% and the A&E
operational target is reviewed yearly. Today each target is a literal buried
in its family's rows CTE, so a target change means hunting through a
1,000-line statement.

Please restructure the pack so that **every pinned target lives in one
`target_contract` CTE** (one row per metric that has a target, e.g. a
`VALUES` list) **joined on once, at presentation**. Metrics without a pinned
target must keep reporting `NULL`. The header's target contract comment
stays the home of the definitions and sources; only the numbers move into
data.

The output must not change at all — same columns, same types, same 2,376
rows, same values.

## Acceptance

Your refactor of `query.sql` (a pristine copy of the reference) still prints
`EQUAL`:

```bash
scripts/check-pack.sh nhs exercises/nhs/reference/performance_pack.sql exercises/nhs/03-targets-as-data/query.sql
```

Note what this check can and cannot verify: it proves you broke nothing; it
cannot prove you did the refactor. `solution.sql` is the intended shape —
compare structure, not just output.
