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

**On Windows**, the R `duckdb` package uses the `windows_amd64_mingw` build and
in-process `INSTALL httpfs` fails, even though the extension URL serves fine over
`curl`. Fetch and gunzip the extension manually, then connect with
`config = list(allow_unsigned_extensions = "true")` and
`LOAD '<path>/httpfs.duckdb_extension'`. Details in `dev/UPSTREAM-ISSUES.md`
(EF2-5).

Note `generate_xpath_report()` cannot reach these yet: it builds
`base_path/<year>/EFILE<year>.duckdb` and gates on `file.exists()`, which rejects
URLs. Run it against a local build instead: `xpath_reports/` holds the TY2009–2024
reports from the September 2026 build (`C:/Users/jlecy/Documents/EFILE_BUILD_SEPT_2026`,
~100 s for all years). Namespace-prefixed paths in them are EF2-11, not real xpaths.

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
