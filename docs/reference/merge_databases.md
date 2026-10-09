# Merge DuckDB databases with schema alignment and timestamped logfile

Merge DuckDB databases with schema alignment and timestamped logfile

## Usage

``` r
merge_databases(
  year,
  missing_urls,
  temp_db_path,
  output_path,
  version = "efile_v2_3",
  source_db = NULL
)
```

## Arguments

- year:

  Integer tax year.

- missing_urls:

  Character vector (for logging).

- temp_db_path:

  Path to temporary DuckDB with new filings.

- output_path:

  Path for final merged DB.

- version:

  S3 version subfolder under duckdb/ (default "efile_v2_3").

- source_db:

  Optional path/URL of the base ("source") database to merge into.
  Defaults to `NULL`, in which case the S3-hosted archive for `year`
  (under `version`) is used. Pass a local `.duckdb` path to merge into
  an already-downloaded archive or for testing.

## Value

Invisibly `output_path`.
