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
| `R/99_utils.R` | `get_table_id()`, `get_header()`, xpath helpers |

`get_table_id()` derives `TABLE_ID` from the **last** bracketed index in an
xpath. Where a repeating group sits at the part level, two different parts can
yield the same `TABLE_ID` — see EF2-1. Treat that function as sensitive.

## Published archives

DuckDB databases, TY2009–2024:

```
https://nccs-efile.s3.dualstack.us-east-1.amazonaws.com/duckdb/efile_v2_2/EFILE<YEAR>.duckdb
```

Flat layout, no year subdirectory. Large — 2.8 GB (2009) to 18.3 GB (2024).

**Query them remotely rather than downloading.** DuckDB reads these over HTTPS
with range requests, pulling only the pages needed:

```sql
LOAD httpfs;
ATTACH 'https://nccs-efile.s3.dualstack.us-east-1.amazonaws.com/duckdb/efile_v2_2/EFILE2009.duckdb'
  AS ef (READ_ONLY);
```

A grouped scan of every Schedule R xpath in TY2009 returns in ~14 s this way.
Tables in each database: `ATTRIBUTES`, `FLATXML`, `KEYS`.

**On Windows**, the R `duckdb` package uses the `windows_amd64_mingw` build and
in-process `INSTALL httpfs` fails, even though the extension URL serves fine over
`curl`. Fetch and gunzip the extension manually, then connect with
`config = list(allow_unsigned_extensions = "true")` and
`LOAD '<path>/httpfs.duckdb_extension'`. Details in `dev/UPSTREAM-ISSUES.md`
(EF2-5).

Note `generate_xpath_report()` cannot reach these yet: it builds
`base_path/<year>/EFILE<year>.duckdb` and gates on `file.exists()`, which rejects
URLs. `xpath_reports/` is empty as a result.

## Consumers

`superstructure` (`../superstructure`) reads the `efile_v2_2` CSV tables and
maintains its own notes in `dev/`. When changing table structure or column
names, that repo's `inst/extdata/concordance.csv` and detectors are affected.

## Before changing table extraction

`build_rdb_table()` selects rows with an **unanchored** `grepl()` against
`TABLE.HEADERS`, so a header that is a substring of another captures the wrong
table's rows. 17 tables are currently affected (EF2-6).

```r
audit_table_headers()   # zero rows == no header can capture another table's xpaths
```

That check needs no data and no database. Run it after any change to
`TABLE.HEADERS`, `get_header()`, or the selection step.

Note `devtools::document()` currently fails here — the declared dependency
`aws.signature` is not installed — so NAMESPACE may need a manual export until
that is resolved.
