# PACK-101 — Mortality disagrees with the death register (41 phantom deaths)

**From:** Clinical governance
**Severity:** High — board pack is wrong
**Kind:** Bug, location known

Since last sprint the pack's crude mortality has been running hot. The
medical examiner's register records **78 in-hospital deaths** across
2023–2025; summing the pack's `mortality_pct` numerators gives **119**.
Rates are inflated in scattered months across the whole three years, and a
month's deaths no longer line up with the month people actually died.

We know where it happened: the sprint's "simplification" in the **mortality
family** replaced the spell timeline's death instant with a flag read off
the patient dimension. The header contract still states the correct rule —
deaths are spells entering the `deceased` state, counted in the month of
that entry.

The warehouse's own README warns about exactly this kind of read; worth
re-reading its "known traps" section before you fix it.

## Acceptance

The pack is byte-identical to the known-good reference:

```bash
scripts/check-pack.sh nhs exercises/nhs/reference/performance_pack.sql exercises/nhs/01-phantom-deaths/query.sql
```

prints `EQUAL`. Fix `query.sql` in place; the full explanation is in
`solution.md` (spoilers).
