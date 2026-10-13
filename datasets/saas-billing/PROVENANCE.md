# Provenance — saas-billing warehouse

`warehouse.duckdb` is not authored here. It is the dimensional export that
[fabulexa-forge](https://github.com/leogodin217/fabulexa_forge) produces from
its published `saas-billing` dataset pack, uploaded unchanged as a release
asset of this repo so learners need no Python to obtain it.

| Field | Value |
|---|---|
| Source pack | `saas-billing.tar.gz` from forge release `datasets-v7` |
| Source pack sha256 | `c0d52636db236af3acc6f3b14bab9085728ee88265bd05e31c687d87490d1926` (41,088,922 bytes) |
| Producer | fabulexa-forge 0.0.1 @ `11a9791` |
| Emit | `base_format_version` 12, `emit.sidecar_sha256` `f0afa455bd6d5b0ab1d65bed443d3a950ba7ff273e16efe4c6595437bad8ebf8` |
| Command | `fabulexa-forge export ./bundle ./dimensional.yaml saas-billing.duckdb --fmt duckdb` (run in the extracted pack) |
| Warehouse sha256 | `f162d1b44b650d5095d51c7c2406ed104effeb561cd9f8fb08fa7159a1b84d0b` |
| Warehouse size | 76,034,048 bytes |
| Release asset | `saas-billing-v3` / `saas-billing.duckdb` |

Two companion files forge wrote with the export sit beside this file, copied
verbatim:

- `README.md` — the companion README (`saas-billing-dimensional-readme.md`):
  the data dictionary and the billing spec the exercises implement.
- `saas-billing-dimensional-manifest.json` — the machine-readable companion
  manifest the README points to. It is the only place the warehouse records
  its foreign-key-style links (`columns[].references`); the export declares no
  constraints.

The command writes the output as `saas-billing.duckdb` rather than the pack's
suggested `saas-billing-star.duckdb` because the companion files are named
after the database stem, and the README refers to the manifest by that name.

To regenerate: `fabulexa-forge datasets get saas-billing` (it verifies the
pack sha256 above), then run the command above in the extracted directory.
DuckDB files are not byte-reproducible across runs, so a regenerated warehouse
gets a new sha256 and a new release tag. Re-vendoring from a new pack can
change the data, so grade every tier's `inherited.sql` against its reference
with `scripts/check.sh` before publishing; all must be `EQUAL`.
