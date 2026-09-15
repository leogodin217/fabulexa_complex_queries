# Provenance — saas-billing warehouse

`warehouse.duckdb` is not authored here. It is the dimensional export that
[fabulexa-forge](https://github.com/leogodin217/fabulexa_forge) produces from
its published `saas-billing` dataset pack, uploaded unchanged as a release
asset of this repo so learners need no Python to obtain it.

| Field | Value |
|---|---|
| Source pack | `saas-billing.tar.gz` from forge release `datasets-v2` |
| Source pack sha256 | `ab6616d82531004867b49fb8850c605b82a021e8691c75868e0cea5e1e913c69` |
| Producer | fabulexa-forge 0.0.1 @ `4644b81` |
| Command | `fabulexa-forge export bundle dimensional.yaml saas-billing.duckdb --fmt duckdb` (run in the extracted pack) |
| Warehouse sha256 | `8f0df8b86cbcb65a8a920657286b17f32a1fffc37875050db97cbe8a5a4a7fef` |
| Warehouse size | 75,509,760 bytes |
| Release asset | `saas-billing-v1` / `saas-billing.duckdb` |

`README.md` beside this file is the companion README forge wrote with the
export (`saas-billing-dimensional-readme.md`), copied verbatim: the data
dictionary and the billing spec the exercises implement.

To regenerate: `fabulexa-forge datasets get saas-billing`, run the command
above, and confirm the pack sha256 matches. DuckDB files are not
byte-reproducible across runs, so a regenerated warehouse gets a new sha256
and a new release tag; the exercises' reference queries are unaffected as long
as the pack sha256 is unchanged.
