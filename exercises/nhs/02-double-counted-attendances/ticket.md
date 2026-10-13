# PACK-102 — A&E attendances don't reconcile with the ED system

**From:** Urgent & emergency care ops
**Severity:** High — national return at risk
**Kind:** Bug, location known

The ED system records **8,467 attendances** over 2023–2025. Summing the
pack's `ae_4hr_pct` denominators gives **11,980**. Monthly figures are
inflated by varying amounts, the specialty mix has drifted, and the 4-hour
percentage itself moved in most months even though nothing changed
clinically.

The regression came in with the attribution rework in the **A&E family**:
the join from attendances to consultant allocations was "simplified". An
attendance should resolve to **the one allocation in force at the arrival
instant** — this is an interval join, and the pack's header says how
interval membership is defined.

## Acceptance

```bash
scripts/check-pack.sh nhs exercises/nhs/reference/performance_pack.sql exercises/nhs/02-double-counted-attendances/query.sql
```

prints `EQUAL`. Fix `query.sql` in place; full explanation in `solution.md`
(spoilers).
