# Changelog

## ef2 2.0.0 (2026-10-09)

The second major release adds the 990-PF and moves the published tables
onto the **concordance990** crosswalks. It covers the work behind three
data releases: `efile_v2_3` and `efilepf_v2_3` (2026-10-06), and
`efile_v3_1` / `efilepf_v3_1` (TY2009–2025, 2026-10-09).

### Breaking changes

- **`TABLE_ID` is fixed width.**
  [`get_table_id()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_table_id.md)
  now writes nine digits in groups of three, e.g. `TID-000-000-001` (1:1
  fields are `TID-000-000-000`), so text order equals repeat order. The
  old format padded to *at least* five digits, so `TID-100000` sorted
  before `TID-20000`. An index above 999,999,999 raises an error.
  Consumers that parse `TABLE_ID` must strip the dashes (EF2-17,
  [\#12](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/12)).
- **Defined row order.**
  [`write_table_output()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_table_output.md)
  sorts both CSV and Parquet by `ORG_EIN, OBJECTID, TABLE_ID`. Before,
  only the Parquet was sorted, and only by `ORG_EIN` (EF2-17,
  [\#12](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/12)).
- **S3 functions default to `version = "efile_v2_3"`.** This applies to
  [`find_missing_urls()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_missing_urls.md),
  [`update_db()`](https://nonprofit-open-data-collective.github.io/ef2/reference/update_db.md),
  [`merge_databases()`](https://nonprofit-open-data-collective.github.io/ef2/reference/merge_databases.md)
  and
  [`download_s3_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/download_s3_database.md)
  ([\#22](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/22)).
- **Table labels follow concordance990 v2.** From `efile_v2_3` on,
  variable names and table assignments come from
  `concordance990::concordance("v2", form = ...)`. Some columns are
  renamed or moved between tables (e.g. `SB_01_CONTRIBUTOR_TYPE` →
  `SB_01_CONTRIBUTOR_NUM`), so code written against `efile_v2_2` needs a
  pass.

### Concordance990 integration

- The `efile_v2_3` archives were relabelled from concordance990 v2
  (1.99.1, `3af11bb`) rather than re-parsed. That is valid because
  [`flatten_xml()`](https://nonprofit-open-data-collective.github.io/ef2/reference/flatten_xml.md)
  assigns labels purely by exact `XPATH2` match. All 137 tables a year
  were rebuilt, including the 16 `-T99-` tables that v2_2 never built.
  Each archive gains a `RELABEL_LOG` table recording the concordance
  used
  ([\#8](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/8),
  [\#9](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/9),
  [\#11](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/11)).
- New
  [`release_concordance()`](https://nonprofit-open-data-collective.github.io/ef2/reference/release_concordance.md)
  returns the concordance a release was labelled with, from a pinned
  copy in `inst/extdata/concordance-<release>.csv.gz`. Copies are pinned
  for `efile_v2_3`, `efile_v3_1` and `efilepf_v3_1`. They are pinned
  rather than read live because later concordance990 releases return
  different rows
  ([\#22](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/22),
  [\#27](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/27)).
- New
  [`db_release()`](https://nonprofit-open-data-collective.github.io/ef2/reference/db_release.md)
  reads the release name from an archive’s `RELABEL_LOG`.
- [`update_db()`](https://nonprofit-open-data-collective.github.io/ef2/reference/update_db.md)
  with `ccf = NULL` now labels new filings with the archive’s own
  release concordance. Before, it always used the v1 master concordance,
  which would have mixed two label sets in one `FLATXML`. It stops when
  no pinned concordance exists for the release
  ([\#22](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/22)).
- [`merge_databases()`](https://nonprofit-open-data-collective.github.io/ef2/reference/merge_databases.md)
  copies `RELABEL_LOG` and `REPAIR_LOG` from the source archive
  ([\#22](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/22)).
- New
  [`compare_releases()`](https://nonprofit-open-data-collective.github.io/ef2/reference/compare_releases.md)
  and
  [`write_release_notes()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_release_notes.md)
  compare two releases of the published tables, from local folders or S3
  prefixes. They report tables added or dropped, row and column changes,
  filings by tax year, and xpaths newly mapped, dropped or moved between
  two concordances. New helper
  [`condense_years()`](https://nonprofit-open-data-collective.github.io/ef2/reference/condense_years.md)
  ([\#25](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/25)).

### 990-PF support

- [`get_keys()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_keys.md)
  reads the amended-return flag on 990-PF returns
  ([\#6](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/6)).
- [`get_table_headers()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_table_headers.md)
  adds header xpaths for 52 990-PF repeating-group tables (102 header
  paths), for both schema eras
  ([\#20](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/20)).
- [`flatten_xml()`](https://nonprofit-open-data-collective.github.io/ef2/reference/flatten_xml.md)
  strips repeat indices of any width from `XPATH2`. The old regex
  stopped at five digits, so from the 100,000th repeat of a group the
  rows matched no concordance xpath and reached no table. One 990-PF
  filing a year in TY2020–2023 hit this (EF2-16,
  [\#10](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/10)).
- The `efilepf_v2_3` and `efilepf_v3_1` releases publish 84 (later 83)
  990-PF tables a year as CSV and Parquet: `PF-P00` … `PF-P17`, the
  `PF-P99-Txx` attachment tables, the shared header and signature
  tables, and the public 990-PF Schedule B. `multi_value` fields are
  joined with `;` in filing order instead of keeping one value (EF2-13,
  [\#13](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/13)).

### Parsing and build robustness

- **Large returns parse in linear time.**
  [`get_flat_xml()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_flat_xml.md)
  took about 20 minutes on a 31.5 MB 990-PF return; it now takes about 1
  minute, with identical output. New
  [`xml_ns_strip_fast()`](https://nonprofit-open-data-collective.github.io/ef2/reference/xml_ns_strip_fast.md)
  and
  [`get_xml_paths()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_xml_paths.md)
  replace
  [`xml2::xml_ns_strip()`](http://xml2.r-lib.org/reference/xml_ns_strip.md)
  and [`xml2::xml_path()`](http://xml2.r-lib.org/reference/xml_path.md),
  and
  [`find_parent_nodes()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_parent_nodes.md),
  [`find_terminal_nodes()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_terminal_nodes.md)
  and
  [`get_table_id()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_table_id.md)
  are vectorized
  ([\#7](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/7)).
- **`irs:`-prefixed returns.** New
  [`xml_prefix_strip()`](https://nonprofit-open-data-collective.github.io/ef2/reference/xml_prefix_strip.md)
  re-parses the few returns that prefix every element, which previously
  got all-NA `KEYS` and prefixed xpaths (EF2-11,
  [\#7](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/7)).
- **Download timeout.**
  [`get_flat_xml()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_flat_xml.md)
  takes `timeout = 120`. A stalled request used to block a worker, and
  so the whole year, indefinitely (EF2-15,
  [\#7](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/7)).
- **Merges.** New
  [`collect_worker_dbs()`](https://nonprofit-open-data-collective.github.io/ef2/reference/collect_worker_dbs.md)
  and `merge_duckdbs(skip_existing = TRUE)` merge every worker shard and
  never a filing twice (EF2-14,
  [\#7](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/7)).
- **Duplicate filings.** New
  [`dedupe_urls()`](https://nonprofit-open-data-collective.github.io/ef2/reference/dedupe_urls.md)
  drops repeated filings from a build list by ObjectId, and
  [`build_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_database.md)
  applies it before batching. New
  [`check_unique_keys()`](https://nonprofit-open-data-collective.github.io/ef2/reference/check_unique_keys.md)
  stops after a merge if `KEYS` holds any `OBJECTID` twice. Filings the
  GTDC index listed twice had been built twice: about 5% of TY2020 rows
  (EF2-19,
  [\#17](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/17)).
- **Shared batch queue.**
  [`build_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_database.md)
  workers claim batches from a shared queue
  ([`run_batch_queue()`](https://nonprofit-open-data-collective.github.io/ef2/reference/run_batch_queue.md))
  instead of fixed per-worker lists, so one slow filing no longer idles
  the other workers. New
  [`release_claimed_batches()`](https://nonprofit-open-data-collective.github.io/ef2/reference/release_claimed_batches.md)
  clears stale claims.
  [`merge_duckdbs()`](https://nonprofit-open-data-collective.github.io/ef2/reference/merge_duckdbs.md)
  no longer crashes on an empty shard (EF2-20,
  [\#28](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/28)).
- [`build_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_database.md)
  evaluates its arguments up front, so
  [`update_db()`](https://nonprofit-open-data-collective.github.io/ef2/reference/update_db.md)
  no longer ships the full index to every worker
  ([\#24](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/24)).
- [`update_db()`](https://nonprofit-open-data-collective.github.io/ef2/reference/update_db.md)
  can update a local archive in place with `source_db =`
  ([\#16](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/16)).

### Indices and the patch archive

- New
  [`list_gt_indices()`](https://nonprofit-open-data-collective.github.io/ef2/reference/list_gt_indices.md)
  lists the GTDC bucket directly.
  [`find_current_index_full()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_current_index_full.md)
  and
  [`find_current_index_batch()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_current_index_batch.md)
  now find the newest index however old it is, and fall back to probing
  dates if the listing fails
  ([\#14](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/14)).
- New patch-index workflow (`R/12_patch_index.R`) for IRS filings the
  GTDC index never listed (EF2-18,
  [\#16](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/16)):
  [`get_irs_index()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_irs_index.md),
  [`get_irs_zip_urls()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_irs_zip_urls.md),
  [`match_batch_zips()`](https://nonprofit-open-data-collective.github.io/ef2/reference/match_batch_zips.md),
  [`diff_irs_gt()`](https://nonprofit-open-data-collective.github.io/ef2/reference/diff_irs_gt.md),
  [`fetch_irs_xml()`](https://nonprofit-open-data-collective.github.io/ef2/reference/fetch_irs_xml.md),
  [`read_return_headers()`](https://nonprofit-open-data-collective.github.io/ef2/reference/read_return_headers.md),
  [`build_patch_index()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_patch_index.md),
  [`upload_patch()`](https://nonprofit-open-data-collective.github.io/ef2/reference/upload_patch.md)
  and
  [`combine_index()`](https://nonprofit-open-data-collective.github.io/ef2/reference/combine_index.md).
  [`stream_unzip()`](https://nonprofit-open-data-collective.github.io/ef2/reference/stream_unzip.md)
  and
  [`info_unzip()`](https://nonprofit-open-data-collective.github.io/ef2/reference/info_unzip.md)
  handle zips that
  [`utils::unzip()`](https://rdrr.io/r/utils/unzip.html) cannot open.
  The `v2_3` patch re-hosts 184,165 filings, which `efile_v3_1`
  includes.

### Tables

- `F9-P00-T00-HEADER` gains `F9_00_ORG_EXEMPT_TYPE` (`"501c3"`,
  `"4947a1"`, `"527"`, …). The subsection number is an XML attribute, so
  until now the tables said only *that* an organization was a 501(c)
  other than (3). It is derived by
  [`exempt_type_sql()`](https://nonprofit-open-data-collective.github.io/ef2/reference/exempt_type_sql.md)
  /
  [`add_exempt_type()`](https://nonprofit-open-data-collective.github.io/ef2/reference/add_exempt_type.md)
  (EF2-12,
  [\#19](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/19)).

### Documentation

- `dev/UPSTREAM-ISSUES.md` records EF2-11 through EF2-20, and a build
  record for each data release
  ([\#8](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/8),
  [\#9](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/9),
  [\#13](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/13),
  [\#15](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/15),
  [\#18](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/18),
  [\#23](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/23),
  [\#26](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/26)).

## ef2 1.0.0 (2026-09-24)

### Origins: a second generation of irs990efile

ef2 is a ground-up rewrite of
[irs990efile](https://github.com/Nonprofit-Open-Data-Collective/irs990efile),
the package that first turned IRS 990 e-file XML into the NCCS efile
tables.

irs990efile built the tables directly from the XML. For every filing it
ran some 140 table builders (`BUILD_F9_P01_T00_SUMMARY()` and so on),
each querying the document for its own xpaths, and held the results in
memory. A tax year took about three days. Nothing between the raw XML
and the finished tables was kept, so fixing one table, adding one, or
recovering from a failed run meant downloading and parsing every filing
again.

ef2 splits the work into two stages and **flattens each XML file once**:

1.  **Flatten.**
    [`flatten_xml()`](https://nonprofit-open-data-collective.github.io/ef2/reference/flatten_xml.md)
    /
    [`get_flat_xml()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_flat_xml.md)
    turn each filing into a long table, one row per node, with its
    xpath, its concordance variable name and table, and its value. The
    rows go into one DuckDB archive per tax year (`KEYS`, `FLATXML`,
    `ATTRIBUTES`). Filings are processed in batches by parallel workers,
    each writing its own shard, so a bad document affects only its
    batch, and finished batches survive an interruption.
2.  **Extract.** Tables are SQL selections and pivots over the flattened
    archive
    ([`extract_csv_tables()`](https://nonprofit-open-data-collective.github.io/ef2/reference/extract_csv_tables.md),
    [`build_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_table.md),
    [`build_rdb_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_rdb_table.md)).
    No XML is read at this stage, so a table can be rebuilt, added or
    corrected in minutes without re-parsing anything.

A tax year now takes about 15 minutes to build, against about three
days, and the flattened archives are themselves published. They can be
queried remotely with DuckDB, and they can be updated by appending new
filings rather than rebuilt.

### Path to 1.0.0

- **2025-03 – 2025-10.** Initial package. The first stable version was
  published 2025-10-28: concordance mapping, batch files, XML
  flattening, DuckDB assembly, updates, table extraction and xpath
  reports.
- **2026-07-10. First stable release.** The irs990efile helpers ef2
  depended on were ported in, so ef2 runs as a free-standing package.
  Adds vignettes and a pkgdown site.

### Updating archives (2026-08)

- [`build_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_database.md)
  and
  [`merge_databases()`](https://nonprofit-open-data-collective.github.io/ef2/reference/merge_databases.md)
  accept character years. They used to fail inside
  [`update_db()`](https://nonprofit-open-data-collective.github.io/ef2/reference/update_db.md)
  with a [`sprintf()`](https://rdrr.io/r/base/sprintf.html) format
  error.
- [`merge_databases()`](https://nonprofit-open-data-collective.github.io/ef2/reference/merge_databases.md)
  takes `source_db` to merge into a local archive.
- New
  [`download_s3_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/download_s3_database.md)
  and
  [`append_to_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/append_to_database.md)
  download an archive once and append new filings in place. Streaming a
  25 GB archive through httpfs was impractically slow; the TY2022 update
  appended 1,685 filings in about 3 seconds.
- `build_database(workers =)` overrides the worker cap. Flattening is
  network-bound, so workers may exceed the core count.
- `dev/update-databases.R` and `dev/update-chunked.R` script chunked,
  resumable updates for large years.

### Table extraction

- **Header collisions fixed (EF2-6).**
  [`build_rdb_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_rdb_table.md)
  selected rows with an unanchored regex against the table headers, so a
  header that was a substring of another captured the wrong table’s
  rows. It now selects on `RDB_TABLE` by default
  (`selection = "rdb_table"`); the header path is kept as
  `selection = "header"` for diffing. New
  [`audit_table_headers()`](https://nonprofit-open-data-collective.github.io/ef2/reference/audit_table_headers.md)
  checks the headers without any data. A TY2010 rebuild changed 23 of
  112 tables and validated all of them against `FLATXML`.
- **Parquet output.**
  [`build_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_table.md),
  [`build_rdb_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_rdb_table.md)
  and
  [`extract_csv_tables()`](https://nonprofit-open-data-collective.github.io/ef2/reference/extract_csv_tables.md)
  take `output = c("csv", "parquet", "both")`; `"csv"` is the default
  and unchanged. New
  [`write_table_output()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_table_output.md)
  writes both formats from the same materialised table, so the Parquet
  is never a re-parse of the CSV. `normalize_empty = TRUE` folds `''` to
  NULL so the two agree. New
  [`verify_table_output()`](https://nonprofit-open-data-collective.github.io/ef2/reference/verify_table_output.md)
  checks a CSV/Parquet pair by row hashes
  ([\#3](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/3)).
- The packaged concordance is synced with master (one missing 990-EZ
  xpath)
  ([\#4](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/4)).

### Xpath reports

- [`generate_xpath_report()`](https://nonprofit-open-data-collective.github.io/ef2/reference/generate_xpath_report.md)
  opens databases read-only, adds `count_filings` (distinct filings per
  xpath), and no longer double counts on a rerun.
  [`get_type()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_type.md)
  is called once on all xpaths. Reports for TY2009–2024 are in
  `xpath_reports/`
  ([\#5](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/5)).

### Documentation

- New `dev/UPSTREAM-ISSUES.md`, the register of known defects in the
  published tables (EF2-1 to EF2-11), and `CLAUDE.md`.
- Build scripts for a full TY2009–2024 rebuild in `dev/`
  ([\#4](https://github.com/Nonprofit-Open-Data-Collective/ef2/issues/4)).
