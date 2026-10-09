# Update the DuckDB database for a given tax year

Update the DuckDB database for a given tax year

## Usage

``` r
update_db(
  year,
  index,
  path = ".",
  version = "efile_v2_3",
  source_db = NULL,
  ccf = NULL,
  workers = NULL
)
```

## Arguments

- year:

  Integer tax year.

- index:

  Data frame with TaxYear and URL columns.

- path:

  Directory for the temporary and merged database files.

- version:

  S3 version subfolder under duckdb/ (default "efile_v2_3").

- source_db:

  Optional path to a local `.duckdb`. When given, missing filings are
  found against it and appended to it **in place** with
  [`append_to_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/append_to_database.md);
  nothing is read from or written to S3.

- ccf:

  Concordance used to label the new filings (passed to
  [`build_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_database.md)).
  New filings must carry the same labels as the archive. `NULL`
  (default) uses
  [`release_concordance()`](https://nonprofit-open-data-collective.github.io/ef2/reference/release_concordance.md)
  for the archive's release: `version` for an S3 archive, or the release
  recorded in `source_db`'s `RELABEL_LOG` for a local one (falling back
  to
  [`get_concordance()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_concordance.md)
  when it has none). A release with no packaged concordance, such as
  `efilepf_v2_3`, stops with an error; pass `ccf` for those.

- workers:

  Passed to
  [`build_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_database.md).

## Value

Invisibly path to merged database or NULL.
