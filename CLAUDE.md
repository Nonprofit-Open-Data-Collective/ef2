# ef2

Retrieves, parses and flattens IRS 990 e-file XML into relational form: schema
alignment, batch processing, DuckDB integration, and the published CSV tables.

This package is **upstream**. Its output is consumed by `superstructure` and
others, so a defect here propagates silently into other people's analyses.

## Read before changing anything

**`dev/UPSTREAM-ISSUES.md` is the register of known defects in the tables this
package produces.** Read it first. It records what is wrong, what has already
been ruled out, and — for the main open item — which cheap test to run before
writing any code. Several findings there were expensive to establish downstream;
rediscovering them is pure waste.

It also draws a line that keeps getting blurred:

| Finding | Belongs in |
|---|---|
| The table is wrong, malformed, or mis-parsed | `dev/UPSTREAM-ISSUES.md` |
| A filer answered a form field inconsistently | not a bug here — this package reproduced the filing faithfully |
| A consumer read a correct table incorrectly | that consumer's own notes |

A person's name sitting in `BusinessName` is the second kind. Do not "fix" it.

## Pipeline shape

| Module | Role |
|---|---|
| `R/01_concordance.R` | xpath → variable name / table mapping |
| `R/03_flatten_xml.R` | XML → long form; assigns `XPATH2`, `TABLE_ID`, `RDB_TABLE` |
| `R/04_write_to_duckdb.R`, `R/05_build_database.R` | DuckDB assembly |
| `R/06_update_db.R` | incremental updates |
| `R/08_extract_csv_tables.R` | long → wide; `pivot_wider()` on `OBJECTID` + `TABLE_ID` |
| `R/09_xpath_reports.R` | xpath usage reports across years |
| `R/11_write_table_output.R` | CSV and/or Parquet output; round-trip verification |
| `R/99_utils.R` | `get_table_id()`, `get_header()`, xpath helpers |

`get_table_id()` derives `TABLE_ID` from the **last** bracketed index in an
xpath. Where a repeating group sits at the part level, two different parts can
yield the same `TABLE_ID` — see EF2-1. Treat that function as sensitive.
Its format is fixed-width, `TID-000-000-001`, so text order equals repeat
order (EF2-17); published tables are sorted `ORG_EIN, OBJECTID, TABLE_ID`.

## Published archives

DuckDB databases, TY2009–2024. **`efile_v2_3` is current**; `efile_v2_2` stays
published, unchanged:

```
https://nccs-efile.s3.dualstack.us-east-1.amazonaws.com/duckdb/efile_v2_3/EFILE<YEAR>.duckdb
https://nccs-efile.s3.dualstack.us-east-1.amazonaws.com/duckdb/efile_v2_2/EFILE<YEAR>.duckdb
```

Flat layout, no year subdirectory. Large — v2_3 runs 2.9 GB (2009) to 26.3 GB (2023).

Tables, CSV + Parquet, flat as `<TABLE>-<YEAR>.CSV` / `.parquet`:

```
https://nccs-efile.s3.dualstack.us-east-1.amazonaws.com/public/efile_v2_3/
```

v2_3 differs from v2_2 in three ways:

- **Labels.** `FLATXML.VARIABLE_NAME` / `RDB_TABLE` were rewritten from
  concordance990 v2 (`concordance("v2", form = "F990")`, 1.99.1), so the tables
  follow the v2 concordance. Some columns are renamed or moved, and a few
  tables' row counts change.
- **Tables.** v2_3 has 137 tables a year, including the 16 `-T99-` tables; v2_2
  had 112 and no T99. The row counts are in
  `public/efile_v2_3/COUNT-OF-ROWS-BY-TABLE-AND-FORMTYPE-EFILE_V2_3.CSV`.
- **EF2-11.** The 43 `irs:`-prefixed filings were re-parsed, so no v2_3 `KEYS`
  row is blank. v2_2 still has the defect.

v2_3 was built by relabelling the v2_2 archives, not by re-parsing XML. That is
valid because `flatten_xml()` assigns labels purely by exact `XPATH2` match. For
a future concordance release, rerun that pipeline rather than a full rebuild:
it takes seconds per year to relabel and about 6 minutes per year to rebuild
the tables. Scripts, logs and the v2_2 → v2_3 diff (`dims_compare.csv`) are in
`C:/Users/jlecy/Documents/EFILE_BUILD_SEPT_2026/V2_3_WORK/`. The record is in
`dev/UPSTREAM-ISSUES.md` under "efile_v2_3".

The S3 functions default to `version = "efile_v2_3"`. `update_db()` labels new
filings with `release_concordance()`, which returns the concordance pinned in
`inst/extdata/concordance-<release>.csv.gz`. It is pinned rather than read from
concordance990, because later concordance990 releases return different rows. A
new release needs its own file there. Without one, `update_db()` stops rather
than mixing two label sets in one archive.

**Query them remotely rather than downloading.** DuckDB reads these over HTTPS
with range requests, pulling only the pages needed:

```sql
LOAD httpfs;
ATTACH 'https://nccs-efile.s3.dualstack.us-east-1.amazonaws.com/duckdb/efile_v2_3/EFILE2009.duckdb'
  AS ef (READ_ONLY);
```

A grouped scan of every Schedule R xpath in TY2009 returns in ~14 s this way
(measured on v2_2).
Tables in each database: `ATTRIBUTES`, `FLATXML`, `KEYS`. v2_3 adds `RELABEL_LOG`,
which records the concordance version used to relabel it.

**On Windows**, R `duckdb` 1.5.5 runs `INSTALL httpfs; LOAD httpfs;` in-process
(verified 2026-10-07). Older builds could not download the extension and needed
a manual fetch plus `allow_unsigned_extensions` (EF2-5). By default extensions
land in a per-session temp directory, so run `INSTALL httpfs` in each session,
or connect with `duckdb(shared_home = TRUE)` to keep it.

`OBJECTID` in every ef2 table carries an `OID-` prefix, added by
`get_object_id()` so it always stays text. IRS (`OBJECT_ID`) and GTDC
(`ObjectId`) indices use the bare 18 digits, so add or strip the prefix when
joining to them.

Note `generate_xpath_report()` cannot reach these yet: it builds
`base_path/<year>/EFILE<year>.duckdb` and gates on `file.exists()`, which rejects
URLs. Run it against a local build instead: `xpath_reports/` holds the TY2009–2024
reports from the September 2026 build (`C:/Users/jlecy/Documents/EFILE_BUILD_SEPT_2026`,
~100 s for all years). Namespace-prefixed paths in them are EF2-11, not real xpaths.

### 990-PF: `efilepf_v2_3`

The 990-PF has its own archives and tables, TY2009–2024, published 2026-10-06:

```
https://nccs-efile.s3.dualstack.us-east-1.amazonaws.com/duckpf/efilepf_v2_3/EFILEPF<YEAR>.duckdb
https://nccs-efile.s3.dualstack.us-east-1.amazonaws.com/public/efilepf_v2_3/
```

- **Archives** run 0.17 GB (2009) to 9.5 GB (2022). Same four tables as v2_3
  (`ATTRIBUTES`, `FLATXML`, `KEYS`, `RELABEL_LOG`).
- **Tables.** There are 84 tables a year as CSV + Parquet, 2,688 files. They
  follow `concordance990::concordance("v2", form = "F990PF")` (commit `56cbffa`,
  fixes 19–21, 2,517 xpaths).
- **Table names.** The tables are `PF-P00` … `PF-P17`, the 40 `PF-P99-Txx`
  attachment tables (`PF_AXnn_` variables), the shared `F9-P00-T00-HEADER` and
  `F9-P02-T00-SIGNATURE`, and the public 990-PF Schedule B (`SB-*`). The PF
  concordance has no `-T99-` tables; the P99 attachment tables play that role,
  and all are built.
- **Separate prefix.** The September 2026 parse stays at
  `duckpf/EFILEPF<YEAR>.duckdb` with the build-time (990 v1) labels. Use the
  `efilepf_v2_3` copies.

It is built the same way as v2_3: relabel, then the ef2 builders. There is one
difference. Variables with `multi_value = TRUE` (states filed, foundation
managers, foreign countries) are joined into one cell with `;` in filing order
instead of keeping only the string-max (EF2-13 fix 2). That is done in a view the
builders read; ef2's builders are unchanged. The relabel also stripped 6+ digit
indices from `XPATH2` (EF2-16). Scripts and logs are in
`C:/Users/jlecy/Documents/EFILE_BUILD_SEPT_2026/PF_V2_3_WORK/`, and the record is
in `dev/UPSTREAM-ISSUES.md` under "efilepf_v2_3".

### Next release: `efile_v3_1` / `efilepf_v3_1` (in progress)

v3_1 adds filings that the GTDC index never listed, and a TY2025 archive. The
record is in `dev/UPSTREAM-ISSUES.md` under EF2-18.

- **Patch.** 184,165 IRS-indexed 990/990EZ/990PF filings were missing from the
  GTDC index of 2026-08-25. They are re-hosted at
  `https://nccs-efile.s3.us-east-1.amazonaws.com/xml2/v2_3_patch/<OBJECT_ID>_public.xml`,
  with `PATCH-INDEX-v2_3-2026-10-07.csv` beside them. They were built with
  `R/12_patch_index.R`. Use `combine_index(gt, patch)` as the build index; it
  keeps GTDC rows where a filing is in both.
- **Labels.** v3_1 follows concordance990 `02de916` (2.0.1), frozen in
  `V3_1_WORK/concordance_v2_F990*.csv`. Relabelling from v2_3 moves 187 990
  xpaths and 26 PF xpaths between tables, and newly maps 59 + 7 xpaths. No
  variable is renamed.
- **Updating a local archive.** Use
  `update_db(year, index, source_db = "<path>.duckdb", ccf = <concordance>)`.
  It finds missing filings by `OBJECTID`, builds them with that concordance,
  and appends in place. Pass the release's concordance: `build_database()`
  otherwise falls back to the v1 master concordance.
- **Install before building.** `build_database()`'s workers are separate R
  sessions that load the ef2 **installed in the R library**. They do not see
  code loaded with `devtools::load_all()`. Run `devtools::install()` first. In
  v3_1 a stale install (2026-09-24, before #16) keyed 103M patch rows as
  `OID-https://…`, which then had to be repaired (EF2-18).
- **Status.** The archives are local only: 17 per form (TY2009–2025)
  in `DUCKDB_V3_1/` and `DUCKDB_PF_V3_1/`, with 6.31M 990 and 1.23M PF
  filings. Relabel, update and repair were done 2026-10-08. The tables are not
  built, and nothing is published under v3_1 yet. When it is, expect
  `duckdb/efile_v3_1/`, `duckpf/efilepf_v3_1/`, and `public/efile[pf]_v3_1/`.

## Consumers

`superstructure` (`../superstructure`) reads the `efile_v2_2` CSV tables and
maintains its own notes in `dev/`. When changing table structure or column
names, that repo's `inst/extdata/concordance.csv` and detectors are affected.
Moving it to v2_3 needs such a pass, because v2_3 renames and moves columns
(e.g. `SB_01_CONTRIBUTOR_TYPE` → `SB_01_CONTRIBUTOR_NUM`).

## Before changing table extraction

`build_rdb_table()` selects rows with an **unanchored** `grepl()` against
`TABLE.HEADERS`, so a header that is a substring of another captures the wrong
table's rows. 17 tables are currently affected (EF2-6).

```r
audit_table_headers()   # zero rows == no header can capture another table's xpaths
```

That check needs no data and no database. Run it after any change to
`TABLE.HEADERS`, `get_header()`, or the selection step.

`devtools::document()` runs clean as of 2026-09-17 — `aws.signature` is now
installed, so the manual-NAMESPACE workaround previously noted here is no longer
needed. (`roxygen2::roxygenise(load_code = "source")` emits spurious
unresolved-link warnings for same-package topics; use `devtools::document()`.)

## Output formats

`build_table()`, `build_rdb_table()` and `extract_csv_tables()` take
`output = c("csv", "parquet", "both")`. `"csv"` is the default and is unchanged.

```r
extract_csv_tables( wd = "...", years = 2009:2024, output = "both" )
```

`get_table_names()` drops the `-T99-` tables by default (`exclude = "T99"`), which
is why v2_2 has none. The v2_3 build passed every `rdb_table` in the concordance990
v2 concordance instead.

Both formats are written by `write_table_output()` from the **same** materialised
`TEMP` table, so Parquet is never a re-parse of the CSV. That matters: FLATXML is
all-VARCHAR (`R/04_write_to_duckdb.R` calls `lapply(df, as.character)`), so this
path involves no type inference anywhere. Re-reading a published CSV does —
`data.table::fread()` and `read.csv()` both cast `ORG_EIN` to integer and destroy
leading zeros on ~4% of rows.

**`normalize_empty = TRUE` is deliberate.** `TEMP` holds two different blanks:
empty strings from `pivot_wider(values_fill = "")` and SQL NULLs from the KEYS
`right_join()`. CSV writes them differently but no reader distinguishes them on
the way back, while Parquet would preserve the distinction — so a literal
conversion yields a Parquet file that disagrees with its own CSV sibling (~12.2M
cells in the TY2023 header table). Folding `''` to NULL in the Parquet reproduces
what every CSV reader already does. Verify any conversion with:

```r
verify_table_output( csv_path, parquet_path, con )   # ok == TRUE
```

That function hashes rows and sorts the hashes rather than ordering by a key —
`OBJECTID` is **not** unique in repeating-group tables, so an `ORDER BY OBJECTID`
digest reports false mismatches.

To convert the CSVs already published on S3, see
`dev/convert-s3-csv-to-parquet.R` (3,586 files, 194 GB, ~6x compression).
