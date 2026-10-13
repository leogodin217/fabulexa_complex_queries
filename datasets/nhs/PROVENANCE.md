# Provenance — nhs warehouse

`warehouse.duckdb` is not authored here. It is the dimensional export that
[fabulexa-forge](https://github.com/leogodin217/fabulexa_forge) produces from
its checked-in `nhs` example bundle, uploaded unchanged as a release asset of
this repo so learners need no Python to obtain it.

| Field | Value |
|---|---|
| Source | forge `docs/examples/nhs/` bundle + `dimensional.yaml` at forge `main` `183ae2f` (PR #47 — SCD-2 `dim_patient`, README overlay with the performance-pack spec) |
| Emit | `base_format_version` 12; bundle passes C1–C15 |
| Export | `dimensional.duckdb`, 19,148,800 bytes |
| Warehouse sha256 | `244439543ba97c2e435c61648d17217a5df7f02344912e8b780deedcb63274aa` |
| Companion README sha256 | `7f932476b97fd7f529c35ecc34ce949edb69532608e07c63232114b9a471fbdf` (50,310 bytes) |
| Companion manifest sha256 | `edeaa781561526a6097b35f71d86d7b476f477f7c614011f6710864a2f737026` (209,771 bytes) |
| Release asset | `nhs-v1` / `nhs.duckdb` — **not yet published**; upload `warehouse.duckdb` under that name when the track ships (setup scripts already carry this tag and sha256) |

Unlike saas-billing, this export was not taken from a published forge datasets
pack: forge's nhs config at `183ae2f` is deliberately ahead of the published
`datasets-v7` nhs pack bytes (datasets-v8 is deferred until this track ships,
when one re-export serves both).

Two companion files forge wrote with the export sit beside this file, copied
verbatim:

- `README.md` — the companion README (`dimensional-dimensional-readme.md`):
  the data dictionary, the NHS metric catalog with national targets, the
  performance-pack reference-query spec, the pinned ambiguities and the known
  traps. It is the authoritative spec the `exercises/nhs/` track implements.
- `dimensional-dimensional-manifest.json` — the machine-readable companion
  manifest the README points to, kept under its exported name because the
  README references it by that name (the export's database stem was
  `dimensional`, so the companions are named `dimensional-dimensional-*`;
  only the readme is renamed, to `README.md`, matching the saas-billing
  layout). It is the only place the warehouse records its foreign-key-style
  links (`columns[].references`); the export declares no constraints.

Known-good facts verified at copy time (2026-10-13): 31 tables;
`dim_patient` 56,075 versions / 14,999 patients / 14,999 current
(`valid_to IS NULL`) / 78 deceased; `[patient_id, valid_from]` has zero
duplicates; as-of joins resolve 1:1 on all 9,322 bookings.

To regenerate: export the nhs bundle with forge at (or after) `183ae2f` using
its `dimensional.yaml`. DuckDB files are not byte-reproducible across runs, so
a regenerated warehouse gets a new sha256 and a new release tag — update
`setup.sh` / `setup.bat` and this file, and re-verify the exercise track
(`exercises/nhs/`) against the new data before publishing.
