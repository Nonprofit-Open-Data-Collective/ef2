# Build an RDB table from multiple header variants

Build an RDB table from multiple header variants

## Usage

``` r
build_rdb_table(
  table_name,
  year,
  TABLE.HEADERS,
  con,
  cc_file,
  post_to_s3 = FALSE,
  selection = c("rdb_table", "header"),
  output = c("csv", "parquet", "both"),
  ...
)
```

## Arguments

- table_name:

  Character table id.

- year:

  Integer year.

- TABLE.HEADERS:

  Named list of header xpaths per table. Used only when
  `selection = "header"`; the default path ignores it.

- con:

  DBI connection.

- cc_file:

  Concordance crosswalk.

- post_to_s3:

  Logical export flag.

- selection:

  Row-selection strategy. `"rdb_table"` (default) filters on the
  `RDB_TABLE` column assigned during flattening – exact, and immune to
  the header-prefix collisions described in EF2-6. `"header"` reproduces
  the legacy unanchored regex, for diffing old against new output only.

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
