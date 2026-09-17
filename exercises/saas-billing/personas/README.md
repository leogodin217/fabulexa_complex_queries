# Ask a colleague

Three people at the company know how billing works, each from a different
angle. Give one of these files to any LLM as its system prompt, then ask
questions the way you would ask a colleague across the desk. They answer in
character, in business language, and they will not write your SQL.

| File | Who | Ask them about |
|---|---|---|
| `manager.md` | Dana, Director of Customer Success | Customers, plans, renewal reviews, why a deal looks the way it does, what a term or a credit is *for* |
| `finance.md` | Ruth, Billing Analyst | The numbers: how each invoice line is computed, which reading of an ambiguous rule the company uses, rounding |
| `data-engineer.md` | Sam, Analytics Engineer | Where things live in the warehouse, which column means what, known data traps |
| `examples.md` | — | Worked invoices for three made-up accounts, in tables. All three colleagues cite it by example number |

## How to use

1. Open a new chat with whatever LLM you have.
2. Paste the whole of one persona file as the system prompt (or as the first
   message, if the tool has no system prompt field).
3. Ask. If they say "that's a question for Ruth", start a new chat with
   `finance.md`.

Each colleague knows their own domain and only that. Dana does not know a
column name. Ruth knows the rule but not the table. Sam knows the table but
will not tell you what the rule should be. Routing the question to the right
person, and translating between their vocabularies, is part of the exercise.

## Why three files, not one

An LLM given all three sets of knowledge in one prompt will leak across them
under pressure, and a manager who happens to know the rounding rule is no
longer teaching you anything. Separate files make the boundary hard.

## Keeping them honest

The persona files describe the rules in prose. The rules themselves are
pinned in `../CONVENTIONS.md`, and `examples.md` is worked by hand from those
conventions. If a convention changes, the table at the end of `examples.md`
says which examples to rework, and the persona whose domain it is should be
re-read for stale wording.
