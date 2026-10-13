# PACK-104 — solution

## The bug

The added filter

```sql
      and cancer_episode.hours_to_diagnosis is not null
```

is a **denominator exclusion**, not a no-op. The FDS definition (header
contract, spec.md, and the warehouse README all state it) is: *a pathway
never diagnosed stays in the denominator as a breach.* 344 of the 2,270
referred pathways in this extract are never diagnosed at all. The filter
silently removes them from the denominator while the numerator (diagnosed
within 672 hours) is untouched — so the percentage can only go up, and it
goes up most in exactly the months where performance was worst (the 2025
staffing shock left the most pathways undiagnosed). May 2025: 37.25% →
54.29%. The trust looks like it recovered; it didn't.

This is the classic survivorship edit: "rows with NULL clocks have nothing
to measure" conflates *no reading yet* with *out of scope*. The never-
diagnosed patient is precisely who the standard exists to count.

(Contrast with the cutoff that is already there: referrals within 672 hours
of the extract end are excluded from **both** sides, with a stated reason —
their clock could not have run its course. That is censoring, declared.
The buggy filter excludes from one side only, undeclared.)

## The fix

Delete the two added lines; the aggregate's `left join`-shaped NULLs
(`hours_to_diagnosis is null`) simply fail the `<= 672` filter in the
numerator and stay in `count(*)`:

```sql
    where cancer_episode.referred_at <= activity_window.extract_end - interval 672 hour
    group by 1
```

## Why it was silent

Same shape, every month still populated, values in range — only 14 monthly
rows change, all upward, which reads as good news. Only the comparison with
the known-good pack (or with the trust's own sense of reality) exposes it.

## Verify

```bash
scripts/check-pack.sh nhs exercises/nhs/reference/performance_pack.sql exercises/nhs/04-fds-miracle/query.sql
```

14 rows differ before the fix; `EQUAL` after.
