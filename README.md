# fabulexa_complex_queries

Learning and teaching tool to help understand, improve and reverse engineer complex 
SQL queries. This repo is intended as a learning tool, but also for those who want to 
create tutorials/vidoes/posts. If you create one, let me know and I will add a link to this 
README. 

Issues and PRs are always welcome. 

**A note on Fabulexa**: Fabulexa is a data-simulation tool that embeds a story into datasets. It has
consumed my non-working life for a year now. That repo is not public, but [Fabulexa Forge](https://github.com/leogodin217/fabulexa_forge)
is. Fabulexa creates the raw data. Forge shapes it the way you want. Source, dimensional or streaming, plus
a few batteries included.

* Additional datasets in other domains useful for teaching different types of lessons. 
* Incremental exports for practicing ETL and changing data
* Corruption library for introducing data-quality issues
* Kafka streaming and a demo mixer board to introduce lag on the producer and consumer side
* Other goodies I can't think of right now.  

## Data

Each dataset (Just one for now) is a finished DuckDB warehouse published as a release asset of
this repo and fetched by a one-line setup script. Saas-billing contains a data warehouse for a 
fictional SaaS company. The data should look realistic enough and the billing process is quite 
complex. See [datasets/saas-billing/README.md](datasets/saas-billing/README.md) for details. 

Download the [DuckDB](releases/download/saas-billing-v1/saas-billing.duckdb) file from releases or use one of the setup scripts in [datasets/saas-billing/]. 


## Exercises

These are tough. Tough enough that I created the dataset and it is still confusing. That tough. 
They are designed to allow practicing something we'll all encounter. Complex queries that are 
difficult to figure out. In particular, I asked Claude to write the most bad-practice filled, obtuse, 
difficult-to-understand queries and Claude came through. Your goal is to understand them and make them 
more readable. I suspect it would have taken days or weeks to do the advanced version early in my career. 

At this time, there are no data-quality issues. The data is good. You have enough to worry about without
having to figure out why price-tier 1 and two have overlapping dates (Yes, I've seen that before). That 
being said, it wouldn't be difficult to introduce those types of errors if anyone is interested. 

**Highly Recommended**: Use [Dbeaver](https://dbeaver.io/) or some other tool with syntax highlighting, formatting
etc. 

To use the grader scripts, you'll need [DuckDB CLI](https://duckdb.org/docs/installation/) in your PATH
(1.3 or newer — older releases run these queries an order of magnitude slowerand can run out 
of memory on the advanced tier). Feel free to roll your own solution. Maybe create views out of 
the queries and create your own comparison query. It's your learning journey, own it! 

Each exercise track pairs a clean **reference** query with an **inherited** one 
— the same result after years of maintenance — and a grader that says exactly 
where a candidate differs from the reference.

```
datasets/<name>/      README.md (data dictionary + spec) · setup.sh / setup.bat · PROVENANCE.md
exercises/<name>/     README.md · CONVENTIONS.md · <tier>/reference.sql · <tier>/inherited.sql
exercises/<name>/personas/   manager.md · finance.md · data-engineer.md · examples.md (ask-a-colleague prompts)
scripts/              run.sh / run.bat · check.sh / check.bat (+ check.sql, the grader)
```

### But Wait, There's More!

Don't feel like you have to do these exercises. Using the docs to generate your own billing queries is a great
exercise in itself. As is reverse engineering the queries and creating your own docs. 
If you are teaching, introducing logic errors in the queries would be useful. Maybe adding
more override tables. If you want to teach/practice ETL, head on over to [Fabulexa Forge](https://github.com/leogodin217/fabulexa_forge)
and use incremental export or introduce data-quality problems. 

In short, this isn't a product. It is a resource with an ecosystem of resources to help you teach, learn or practice. 

## Quick start

```bash
datasets/saas-billing/setup.sh                       # downloads warehouse.duckdb (~75 MB) and verifies it
scripts/run.sh   saas-billing exercises/saas-billing/beginner/inherited.sql
scripts/check.sh saas-billing beginner exercises/saas-billing/beginner/my_query.sql  # EQUAL / DIFFERENT, exit 0 only on EQUAL
```

Windows: `setup.bat`, `run.bat`, `check.bat` — same arguments use \ instead of / in the paths.

## Datasets

| Name | What it is | Tracks |
|---|---|---|
| [`saas-billing`](datasets/saas-billing/README.md) | A B2B SaaS vendor's billing warehouse over five years — accounts, seats, a metered usage firehose, tier ladders, promotions, commits and credits; the facts of a monthly invoice, never the invoice itself | [billing query exercises](exercises/saas-billing/README.md), three tiers |

Warehouses are produced by [fabulexa-forge](https://github.com/leogodin217/fabulexa_forge)
from simulated base-layer emits; each dataset's `PROVENANCE.md` records the
source pack, producer version and digests so it can be regenerated.

## Ask a colleague

Each track ships three persona files under `exercises/<name>/personas/`. Paste
one into any LLM as its system prompt and it answers as a person at the
company: a customer success director who knows the deals, a billing analyst
who knows the numbers, or an analytics engineer who knows the warehouse. Each
knows only their own domain and sends you to a colleague for the rest; none of
them will write SQL. `examples.md` alongside them works the rules by hand in
tables for made-up accounts. See the [personas README](exercises/saas-billing/personas/README.md).

Note from human: This is just something I'm experimenting with. In the real world, we have people to ask. 
Maybe this will mimic that enough to be useful. 

## Grading

`scripts/check.sh <dataset> <tier> <candidate.sql>` runs the tier's reference
and the candidate as temp tables over the read-only warehouse, then compares
column names, types and order, and the multiset of rows (`EXCEPT ALL` both
ways). Exact equality is the bar; the conventions file of each track says
which side of every ambiguity the reference takes, so a `DIFFERENT` verdict
is always attributable.

## Use of LLMs
This repo is 99% written by Claude. I usually do a lot of editing and guidance on these projects
but this one came out pretty good right from the start. I'd rather spend my time doing the exercises
to get some practice in and improving Fabulexa to allow more tools for those who want to teach/practice
data skills. 