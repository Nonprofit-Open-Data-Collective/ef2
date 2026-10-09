# ef2 1.0.0 (2026-09-24)

## Origins: a second generation of irs990efile

ef2 is a ground-up rewrite of
[irs990efile](https://github.com/Nonprofit-Open-Data-Collective/irs990efile),
the package that first turned IRS 990 e-file XML into the NCCS efile tables.

irs990efile built the tables directly from the XML. For every filing it ran
some 140 table builders (`BUILD_F9_P01_T00_SUMMARY()` and so on), each querying
the document for its own xpaths, and held the results in memory. A tax year
took about three days. Nothing between the raw XML and the finished tables was
kept, so fixing one table, adding one, or recovering from a failed run meant
downloading and parsing every filing again.

ef2 splits the work into two stages and **flattens each XML file once**:

1. **Flatten.** `flatten_xml()` / `get_flat_xml()` turn each filing into a long
   table, one row per node, with its xpath, its concordance variable name and
   table, and its value. The rows go into one DuckDB archive per tax year
   (`KEYS`, `FLATXML`, `ATTRIBUTES`). Filings are processed in batches by
   parallel workers, each writing its own shard, so a bad document affects
   only its batch, and finished batches survive an interruption.
2. **Extract.** Tables are SQL selections and pivots over the flattened
   archive (`extract_csv_tables()`, `build_table()`, `build_rdb_table()`). No
   XML is read at this stage, so a table can be rebuilt, added or corrected
   in minutes without re-parsing anything.

A tax year now takes about 15 minutes to build, against about three days, and
the flattened archives are themselves published. They can be queried remotely
with DuckDB, and they can be updated by appending new filings rather than
rebuilt.

## Path to 1.0.0

* **2025-03 – 2025-10.** Initial package. The first stable version was
  published 2025-10-28: concordance mapping, batch files, XML flattening,
  DuckDB assembly, updates, table extraction and xpath reports.
* **2026-07-10. First stable release.** The irs990efile helpers ef2 depended
  on were ported in, so ef2 runs as a free-standing package. Adds vignettes and
  a pkgdown site.

## Updating archives (2026-08)

* `build_database()` and `merge_databases()` accept character years. They
  used to fail inside `update_db()` with a `sprintf()` format error.
* `merge_databases()` takes `source_db` to merge into a local archive.
* New `download_s3_database()` and `append_to_database()` download an archive
  once and append new filings in place. Streaming a 25 GB archive through
  httpfs was impractically slow; the TY2022 update appended 1,685 filings in
  about 3 seconds.
* `build_database(workers =)` overrides the worker cap. Flattening is
  network-bound, so workers may exceed the core count.
* `dev/update-databases.R` and `dev/update-chunked.R` script chunked,
  resumable updates for large years.

## Table extraction

* **Header collisions fixed (EF2-6).** `build_rdb_table()` selected rows with
  an unanchored regex against the table headers, so a header that was a
  substring of another captured the wrong table's rows. It now selects on
  `RDB_TABLE` by default (`selection = "rdb_table"`); the header path is kept
  as `selection = "header"` for diffing. New `audit_table_headers()` checks the
  headers without any data. A TY2010 rebuild changed 23 of 112 tables and
  validated all of them against `FLATXML`.
* **Parquet output.** `build_table()`, `build_rdb_table()` and
  `extract_csv_tables()` take `output = c("csv", "parquet", "both")`; `"csv"`
  is the default and unchanged. New `write_table_output()` writes both formats
  from the same materialised table, so the Parquet is never a re-parse of the
  CSV. `normalize_empty = TRUE` folds `''` to NULL so the two agree. New
  `verify_table_output()` checks a CSV/Parquet pair by row hashes (#3).
* The packaged concordance is synced with master (one missing 990-EZ xpath)
  (#4).

## Xpath reports

* `generate_xpath_report()` opens databases read-only, adds `count_filings`
  (distinct filings per xpath), and no longer double counts on a rerun.
  `get_type()` is called once on all xpaths. Reports for TY2009–2024 are in
  `xpath_reports/` (#5).

## Documentation

* New `dev/UPSTREAM-ISSUES.md`, the register of known defects in the
  published tables (EF2-1 to EF2-11), and `CLAUDE.md`.
* Build scripts for a full TY2009–2024 rebuild in `dev/` (#4).
