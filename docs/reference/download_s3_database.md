# Download an S3-hosted DuckDB archive to a local file

Performs a plain (sequential/multipart) file download of the archived
`EFILE<year>.duckdb` rather than streaming the whole database through
`httpfs` SQL. For large archives (tens of GB) this is dramatically
faster than a `CREATE TABLE AS SELECT *` copy, and produces a local file
that new filings can be appended to directly (see
[`append_to_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/append_to_database.md)).

## Usage

``` r
download_s3_database(
  year,
  version = "efile_v2_3",
  dest = NULL,
  overwrite = FALSE
)
```

## Arguments

- year:

  Tax year (integer or character).

- version:

  S3 version subfolder under duckdb/ (default "efile_v2_3"). Set NULL or
  "" for the unversioned path.

- dest:

  Destination path. Defaults to `EFILE<year>.duckdb` in the working
  directory.

- overwrite:

  Logical; if FALSE (default) and `dest` already exists, the download is
  skipped.

## Value

Invisibly, the local destination path.

## Details

Uses the AWS CLI (`aws s3 cp --no-sign-request`) when available for
multipart parallelism, otherwise falls back to
[`utils::download.file()`](https://rdrr.io/r/utils/download.file.html).
