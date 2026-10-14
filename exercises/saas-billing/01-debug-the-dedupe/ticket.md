# BILL-207 — Seat revenue fell 38% the day the data got "cleaned"

**From:** Ruth (Billing Analyst) — Sam (Analytics Engineer) cc'd
**Severity:** High — the CS dashboard's seat bill is wrong
**Kind:** Bug, location known — understanding it is the deliverable

Since last sprint the seat bill has been running light. Very light: summed
over our full five years it reports **$11.09M** of seat charges where my own
spot-checks reconcile to **$17.89M** — about 38% of seat revenue gone, 417
of our 541 companies affected, every single error downward. Our biggest
account, CMP-00002, is low in essentially every month it has ever been
billed.

And it is not subtle at seat level. USR-000001 held an active seat from
2026-01-23 to 2027-01-14 — HR's roster and the usage log both say so — and
the bill now charges **zero** seat-days for it, ever.

We know which change did it. Last sprint, DQ-412 flagged that
`dim_user_status` fails a `(user_id, valid_from)` uniqueness audit —
thousands of "duplicate" seat versions. The sprint closed the ticket by
adding a dedupe CTE (`seat_version`, right above the seats stage) so the
seat stage reads a cleaned timeline. The audit has been green since. The
bill has been wrong since.

Reverting is not enough. If I just revert, DQ-412 gets reopened and someone
re-lands the same fix in six months. What I need from you:

1. **Make the bill right** — fix `query.sql` in place.
2. **Kill the audit's premise** — a short written answer to: what *are*
   those duplicate `(user_id, valid_from)` days? What does a version whose
   `valid_from` equals its `valid_to` mean, and what history was the dedupe
   deleting? Why does every as-of and overlap join in this repo work fine
   on the "dirty" table — and would the same audit's "fix" on `dim_company`
   be any safer?

The warehouse's own README documents this exact trap in its "Known traps"
section — read it before you touch the query. Sam (the `personas/
data-engineer.md` colleague) knows the dimension's grain; Ruth
(`personas/finance.md`) can reconcile any month you want to spot-check.

## Acceptance

The bill is identical to the beginner reference:

```bash
scripts/check.sh saas-billing beginner exercises/saas-billing/01-debug-the-dedupe/query.sql
```

prints `EQUAL` — and you can answer question 2 without notes. Fix
`query.sql` in place; the full explanation is in `solution.md` (spoilers).
