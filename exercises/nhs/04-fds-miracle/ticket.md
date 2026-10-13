# PACK-104 — Cancer FDS jumped 17 points after a cleanup. Too good to be true?

**From:** Cancer services manager
**Severity:** High — about to be reported upward
**Kind:** Bug, symptom only (a suspect diff is attached)

Last week's board pack had us at **37.25%** against the 28-day Faster
Diagnosis Standard for May 2025. This week's pack says **54.29%** for the
same month. August went 32.14% → 50.00%. Nothing changed on the ground — we
have not diagnosed a single extra patient. The only thing that landed in
between is this "cleanup" in the FDS family:

```diff
     from cancer_episode
     cross join activity_window
     where cancer_episode.referred_at <= activity_window.extract_end - interval 672 hour
+      -- cleanup: pathways with no clock reading carry nothing to measure
+      and cancer_episode.hours_to_diagnosis is not null
     group by 1
```

The author's argument: "a pathway with no diagnosis has no
`hours_from_referral` reading, so there is nothing to measure — filtering
the NULLs is a no-op." It compiles, it runs, every month still has a value.

Is it a no-op? Tell us what this filter actually does to the standard, then
make the pack match the known-good reference again.

## Acceptance

```bash
scripts/check-pack.sh nhs exercises/nhs/reference/performance_pack.sql exercises/nhs/04-fds-miracle/query.sql
```

prints `EQUAL`, and your explanation says *why* the number moved in the
direction it did. Full explanation in `solution.md` (spoilers).
