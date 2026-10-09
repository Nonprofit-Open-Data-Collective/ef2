# Build a structured wide table and optionally export to CSV/S3

`F9-P00-T00-HEADER` also gains the derived `F9_00_ORG_EXEMPT_TYPE`; see
[`add_exempt_type()`](https://nonprofit-open-data-collective.github.io/ef2/reference/add_exempt_type.md).

## Usage

``` r
build_table(
  table_name,
  year,
  con,
  cc_file,
  post_to_s3 = FALSE,
  output = c("csv", "parquet", "both"),
  ...
)
```

## Arguments

- table_name:

  Character table id.

- year:

  Integer year.

- con:

  DBI connection.

- cc_file:

  Concordance crosswalk.

- post_to_s3:

  Logical, if TRUE write to S3 using DuckDB COPY.

- output:

  One of `"csv"` (default, unchanged behaviour), `"parquet"`, or
  `"both"`. Both formats are written from one materialised temp table,
  so the Parquet file is never a re-parse of the CSV. See
  [`write_table_output()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_table_output.md).

- ...:

  Further arguments passed to
  [`write_table_output()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_table_output.md),
  e.g. `normalize_empty`, `sort_key`, `row_group_size`.

## Value

Invisibly the lazy tibble.
