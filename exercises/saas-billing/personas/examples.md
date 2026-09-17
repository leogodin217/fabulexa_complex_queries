# Worked billing examples

Made-up accounts, real rules. Every number below follows the pinned
conventions in `../CONVENTIONS.md`, worked by hand in business language so a
learner can check their own understanding before writing a line of SQL. The
companies here do not exist in the warehouse; the plan terms, rate ladder,
add-on fees and promotion dates are the company's real catalogue.

The three colleagues in this directory (`manager.md`, `finance.md`,
`data-engineer.md`) refer to these examples by number.

## The catalogue everyone works from

| Plan | List seat price | Core units included per seat per month | Free trial | Credit validity |
|---|---|---|---|---|
| Starter | $25 | 40 | 14 days | 90 days |
| Professional | $60 | 75 | 30 days | 180 days |
| Enterprise | $120 | 100 | 30 days | 365 days |

| Product | Billed how | List rate | Ladder |
|---|---|---|---|
| Core | metered | $0.10 / unit | 0–5,000 @ $0.10 · 5,001–25,000 @ $0.08 · 25,001+ @ $0.06 |
| Analytics | metered | $0.25 / unit | 0–1,000 @ $0.25 · 1,001–10,000 @ $0.20 (until 30 Jun 2028) or $0.22 (from 1 Jul 2028) · 10,001+ @ $0.15 |
| API | metered | $0.05 / unit | 0–2,000 @ $0.00 · 2,001+ @ $0.05 |
| Storage | metered | $0.02 / unit | single open band @ $0.02 |
| Workflow | metered | $0.15 / unit | no ladder, flat list rate; launched 1 Jun 2028 |
| SSO | flat add-on | $150 / month | — |
| Premium Support | flat add-on | $500 / month | — |

Promotions: "Spring Push" waives all Analytics usage from 1 March 00:00 to
15 March 00:00 (exclusive) every year 2026 to 2030.

Band bounds are inclusive at both ends and cumulative within the month.

## The made-up accounts

| Company | Plan | Provisioned | Seat price | Pays % of list on usage | Core allowance per seat | Add-ons | Churned |
|---|---|---|---|---|---|---|---|
| Pebble Studio | Starter | 3 Jan 2027 | $25 | 100% | 40 (plan default) | none | no |
| Northwind Robotics | Professional | 20 Feb 2027 09:00 | $60 | 100% | 75 (plan default) | none | October 2027 |
| Harbor Logistics | Enterprise | 8 Nov 2026 | $120, then $132 from 15 May 2027 | 85% from 15 May 2027 | 150 (negotiated) | SSO, Premium Support | no |

---

## Example 1 — Seat proration (Pebble Studio, April 2027)

A seat is billed for the days it was live, in state *active* or *using*. A
seat that is only *provisioned* or already *offboarded* is not billed. April
has 30 days. Pebble's seat price is $25.

| Seat holder | What happened | Billable days | Fraction of a seat |
|---|---|---|---|
| Ana | Live all month | 30 | 1.000000 |
| Ben | Seat went live on 20 April | 20–30 April = 11 | 0.366667 |
| Cara | Seat offboarded on 10 April | 1–9 April = 9 | 0.300000 |
| Dev | Provisioned 5 April, never activated | 0 | 0.000000 |
| **Total** | | | **1.666667** |

Seat fractions are kept to six decimals.

| Line | Working | Amount |
|---|---|---|
| Seat charge | 1.666667 × $25 = 41.666675 | **$41.67** |

Note the offboarding day itself is not billed: Cara's seat was live *up to*
10 April, not *through* it. The activation day is billed: Ben's seat was live
*from* 20 April.

---

## Example 2 — Seat price changes mid-month (Harbor Logistics, May 2027)

Harbor's renewal review on 15 May 2027 raised its seat price from $120 to
$132. Eight seats were live all month.

| Reading | Working | Amount |
|---|---|---|
| Price as of month end (**the rule**) | 8 × $132 | **$1,056.00** |
| Blended by days (not the rule) | 8 × (14/31 × 120 + 17/31 × 132) | $1,012.65 |
| Price at start of month (not the rule) | 8 × $120 | $960.00 |

The same "as of month end" rule fixes the negotiated usage discount and the
Core allowance for the month. Whatever the terms were at the last instant of
the month is what the whole month is billed on.

---

## Example 3 — Usage: trial, promotion, allowance (Northwind Robotics, March and April 2027)

Northwind is Professional: a 30-day trial and 75 included Core units per
seat. It was provisioned 20 February 2027 at 09:00, so its trial runs until
22 March 2027 at 09:00. Four seats were live for all of March and April.

**Core allowance** each month = 4 seats × 75 = 300 units.

### March 2027

Free volume comes off first, session by session. Only then is the allowance
netted against what is left.

| Product | Sessions | Why free / billable | Volume kept |
|---|---|---|---|
| Core | 800 units before 22 Mar 09:00 | in trial | 0 |
| Core | 200 units after 22 Mar 09:00 | billable | 200 |
| Analytics | 400 units on 5 Mar | Spring Push *and* trial | 0 |
| Analytics | 300 units on 20 Mar | trial (promo already over) | 0 |
| Analytics | 1,500 units on 28 Mar | billable | 1,500 |

| Product | Volume kept | Allowance | Net volume rated | Ladder walk | List amount |
|---|---|---|---|---|---|
| Core | 200 | 300 | 0 | — | $0.00 |
| Analytics | 1,500 | none (Core only) | 1,500 | 1,000 @ 0.25 = 250.00 · 500 @ 0.20 = 100.00 | $350.00 |

Usage charge, March = $350.00 × 100% = **$350.00**.

If the allowance had been netted against gross Core volume (1,000 − 300 =
700) and the trial ignored, 700 units would have been rated. They are not.
Allowance is netted against volume that survived the trial and promotion.

### April 2027

| Product | Volume | Allowance | Net rated | Ladder walk | List amount |
|---|---|---|---|---|---|
| Core | 2,300 | 300 | 2,000 | 2,000 @ 0.10 | $200.00 |
| Analytics | 800 | — | 800 | 800 @ 0.25 | $200.00 |

Usage charge, April = **$400.00**.

Unused allowance does not carry forward. March's 300 spare units are gone.

---

## Example 4 — Walking the ladder, the flat-rate product, the repriced band (Harbor Logistics, September 2028)

Harbor has 20 live seats and a negotiated allowance of 150 Core units per
seat, so 3,000 Core units are included. It pays 85% of list on usage.

| Product | Gross volume | Allowance | Net volume | Band | Units in band | Rate | Band amount |
|---|---|---|---|---|---|---|---|
| Core | 40,000 | 3,000 | 37,000 | 0–5,000 | 5,000 | 0.10 | 500.00 |
| | | | | 5,001–25,000 | 20,000 | 0.08 | 1,600.00 |
| | | | | 25,001+ | 12,000 | 0.06 | 720.00 |
| Analytics | 4,000 | — | 4,000 | 0–1,000 | 1,000 | 0.25 | 250.00 |
| | | | | 1,001–10,000 | 3,000 | **0.22** | 660.00 |
| API | 6,000 | — | 6,000 | 0–2,000 | 2,000 | 0.00 | 0.00 |
| | | | | 2,001+ | 4,000 | 0.05 | 200.00 |
| Storage | 50,000 | — | 50,000 | open band | 50,000 | 0.02 | 1,000.00 |
| Workflow | 3,000 | — | 3,000 | no ladder | 3,000 | 0.15 list | 450.00 |

| Step | Working | Amount |
|---|---|---|
| Sum of list amounts | 2,820.00 + 910.00 + 200.00 + 1,000.00 + 450.00 | $5,380.00 |
| Negotiated discount | × 85% | **$4,573.00** |

Two things to notice.

- **Units in a band** = min(net volume, band top) − (band bottom − 1), floored
  at zero. The 5,001–25,000 band holds 20,000 units, not 19,999.
- **The Analytics band-2 reprice.** The 1,001–10,000 band was $0.20 until 30
  June 2028 and $0.22 from 1 July 2028. September 2028 uses $0.22. June 2028
  would have used $0.20, because the price in force at *month end* is used,
  same as seat price. The same 4,000 Analytics units cost $850.00 list in
  June and $910.00 list in July.

---

## Example 5 — A negotiated ladder priced as a percentage of list (Harbor Logistics, February 2029)

At its January 2029 review Harbor negotiated its own Core ladder, expressed
as a percentage of the $0.10 list rate rather than as a per-unit price.
Everything else is unchanged from Example 4: same volumes, same 3,000 unit
allowance, and Harbor still pays 85% of list on its other products.

| Product | Net volume | Band | Units | Price | Band amount |
|---|---|---|---|---|---|
| Core | 37,000 | 0–10,000 | 10,000 | 70% of $0.10 = 0.07 | 700.00 |
| | | 10,001+ | 27,000 | 55% of $0.10 = 0.055 | 1,485.00 |

| Step | Working | Amount |
|---|---|---|
| Core, custom ladder | 700.00 + 1,485.00, **no further discount** | $2,185.00 |
| Everything else at list | 910.00 + 200.00 + 1,000.00 + 450.00 = 2,560.00, × 85% | $2,176.00 |
| Usage charge | | **$4,361.00** |

A percent-of-list band already *is* the discount for that band. Applying
Harbor's 85% on top of it would discount twice. Had the negotiated ladder
been written as per-unit prices instead (say $0.07 and $0.055 as rates), the
85% would still apply to it, because a per-unit price is a replacement for
the list ladder, not for the discount.

The negotiated ladder replaces the published one only for the products it
names. Harbor's Analytics, API, Storage and Workflow still rate on the
published ladder.

---

## Example 6 — Commitments (Harbor Logistics, July 2028 to June 2029)

Enterprise accounts commit to a usage spend for each review term and pay it
up front in the month the term starts. Each month's usage charge draws the
prepaid balance down. Usage above the balance is billed as overage. Unused
balance is forfeited when the term ends.

A term starts at a review that *changes* the commitment. A review that leaves
the commitment as it was does not start a new term.

**Term A**: the 15 July 2028 review set a commitment of $12,000. The 15
January 2029 review changed it to $25,000, which ended Term A and started
Term B.

| Month | Commit billed | Usage charge | Balance before | Drawn from commit | Balance after | Usage billed as overage |
|---|---|---|---|---|---|---|
| Jul 2028 | 12,000.00 | 3,500.00 | 12,000.00 | 3,500.00 | 8,500.00 | 0.00 |
| Aug 2028 | 0.00 | 4,200.00 | 8,500.00 | 4,200.00 | 4,300.00 | 0.00 |
| Sep 2028 | 0.00 | 4,573.00 | 4,300.00 | 4,300.00 | 0.00 | 273.00 |
| Oct 2028 | 0.00 | 3,900.00 | 0.00 | 0.00 | 0.00 | 3,900.00 |
| Nov 2028 | 0.00 | 2,400.00 | 0.00 | 0.00 | 0.00 | 2,400.00 |
| Dec 2028 | 0.00 | 3,100.00 | 0.00 | 0.00 | 0.00 | 3,100.00 |

**Term B**: $25,000 committed, billed in January 2029.

| Month | Commit billed | Usage charge | Balance before | Drawn from commit | Balance after |
|---|---|---|---|---|---|
| Jan 2029 | 25,000.00 | 3,600.00 | 25,000.00 | 3,600.00 | 21,400.00 |
| Feb 2029 | 0.00 | 4,361.00 | 21,400.00 | 4,361.00 | 17,039.00 |
| Mar 2029 | 0.00 | 3,800.00 | 17,039.00 | 3,800.00 | 13,239.00 |
| Apr 2029 | 0.00 | 3,900.00 | 13,239.00 | 3,900.00 | 9,339.00 |
| May 2029 | 0.00 | 3,200.00 | 9,339.00 | 3,200.00 | 6,139.00 |
| Jun 2029 | 0.00 | 3,300.00 | 6,139.00 | 3,300.00 | 2,839.00 |

The July 2029 review changed the commitment again, so Term B ended with
$2,839.00 unused. That money is forfeited. No line on any invoice shows it.

On the invoice, the usage charge line always shows the full usage charge.
The commitment appears as two separate lines: **commit billed** (positive, in
the month a term starts) and **commit drawn** (negative, every month there is
balance). The month's term is the one in force at month end, so a commitment
set on the 15th draws down that same month's usage.

Add-ons are never drawn from a commitment. Only usage is.

---

## Example 7 — Credits (Northwind Robotics, 2027)

A credit is issued to a company at a review, for goodwill, an SLA breach or a
billing error. It is applied to invoices oldest-credit-first, from the month
it was issued through the month it expires, and any remainder carries to the
next month. Whatever is left at expiry is forfeited. An invoice never goes
below zero. Northwind is Professional, so credits are valid for 180 days.

| Credit | Reason | Issued | Expires | Open in months |
|---|---|---|---|---|
| A, $500 | goodwill | 10 Mar 2027 | 6 Sep 2027 | March through September 2027 |
| B, $300 | billing error | 25 Mar 2027 | 21 Sep 2027 | March through September 2027 |

Northwind's invoices before credits (four seats at $60, plus the usage from
Example 3, no add-ons, no commitment):

| Month | Seats | Usage | Before credits | Credit A applied | Credit B applied | Total due | A remaining | B remaining |
|---|---|---|---|---|---|---|---|---|
| Mar 2027 | 240.00 | 350.00 | 590.00 | 500.00 | 90.00 | **0.00** | 0.00 | 210.00 |
| Apr 2027 | 240.00 | 400.00 | 640.00 | 0.00 | 210.00 | **430.00** | 0.00 | 0.00 |

Credit A is older, so it is consumed first and in full. Credit B covers the
remaining $90 in March and carries $210 into April.

**Expiry and churn.** A third credit, C for $2,000 (SLA breach), was issued
20 August 2027 and would run to 16 February 2028. Northwind churned in
October 2027, and nothing after the churn month is billed. Suppose its August,
September and October invoices were $640 each before credits.

| Month | Before credits | Credit C applied | Total due | C remaining |
|---|---|---|---|---|
| Aug 2027 | 640.00 | 640.00 | 0.00 | 1,360.00 |
| Sep 2027 | 640.00 | 640.00 | 0.00 | 720.00 |
| Oct 2027 | 640.00 | 640.00 | 0.00 | 80.00 |

There is no November invoice, so the last $80 is never applied. A credit
issued *after* the churn month is never applied at all.

---

## Example 8 — One complete invoice (Harbor Logistics, September 2028)

Pulling Examples 2, 4 and 6 together, plus a $250 SLA-breach credit issued
5 September 2028.

| Line | Working | Amount |
|---|---|---|
| Seat charge | 20 seats × $132 | 2,640.00 |
| Usage charge | Example 4 | 4,573.00 |
| Add-on charge | SSO 150 + Premium Support 500 | 650.00 |
| Commit billed | no term started this month | 0.00 |
| Commit drawn | Example 6, remaining Term A balance | −4,300.00 |
| Credit applied | $250 credit, fully consumed | −250.00 |
| **Total due** | 2,640 + 4,573 + 650 + 0 − 4,300 − 250 | **3,313.00** |

---

## Rounding, in one place

Every line is carried at full precision through every stage and rounded
**once**, to cents, at the very end. The total due is the sum of the six
*rounded* lines, so the printed total always equals the printed lines.
Rounding is half away from zero: 41.665 becomes 41.67, and 2.345 becomes 2.35.
The only other rounding anywhere is the seat fraction, kept to six decimals.

---

## Which example demonstrates which convention

| Convention | Example |
|---|---|
| Seat-days over days in month; provisioned and offboarded days unbilled | 1 |
| Seat price, discount and allowance read as of month end | 2, 4 |
| Trial and promotion volume removed before the allowance | 3 |
| Allowance is Core only, does not carry forward | 3 |
| Inclusive band bounds, units in a band | 4 |
| Repriced band is a new price with its own start date | 4 |
| Product with no ladder rates at flat list | 4 |
| Percent-of-list custom band is not discounted again | 5 |
| Custom ladder replaces only the products it names | 5 |
| Term boundaries: only a *changed* commitment starts a term | 6 |
| Commit billed up front, drawn monthly, overage, forfeit | 6 |
| Add-ons never drawn from a commitment | 6 |
| Credits oldest-first, carry forward, expire, never below zero | 7 |
| Nothing billed after the churn month | 7 |
| One rounding, at the end; total is the sum of rounded lines | 8, Rounding |
