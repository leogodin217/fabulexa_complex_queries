# PACK-109 — Something in the pack is wrong. Nobody can say what.

**From:** Head of performance
**Severity:** High — trust in the pack itself
**Kind:** Bug, no symptom.

A "no-op tidy-up" PR touched the pack last sprint. It ran clean, the row
count didn't move, and no metric owner has filed a complaint. But the
pre-change pack was archived as the known-good reference, and a routine
set-diff says the two no longer agree.

That diff is your only lead. No symptom, no family name, no suspect code.

1. Run the diff and read what it tells you — *which* rows differ is itself
   the evidence: which metric, which months, which direction.
2. Work from the differing rows back to the code, find the edit, and say —
   in the ticket-closure comment — what principle the tidy-up violated. The
   pack's own header contract states the rule that was broken.
3. Restore the pack.

## Acceptance

```bash
scripts/check-pack.sh nhs exercises/nhs/reference/performance_pack.sql exercises/nhs/09-regression-hunt/query.sql
```

prints `EQUAL`, and your closure comment explains the regression. Full
explanation in `solution.md`.
