# Extract All IRS 990 Tables from DuckDB Databases

Iterates over a set of DuckDB database files, one per tax year, and
extracts all tables defined in the IRS 990 efile schema. The function
builds both header tables T00 and data tables T01 to T99 for each year,
saving them into the database as flat relational tables.

## Usage

``` r
extract_csv_tables(
  wd,
  years,
  table_names = NULL,
  ccf = NULL,
  table_headers = NULL,
  output = c("csv", "parquet", "both"),
  ...
)
```

## Arguments

- wd:

  Character. Base working directory containing yearly subfolders with
  DuckDB databases.

- years:

  Integer vector. Tax years to process (e.g., 2009:2024).

- table_names:

  Character vector of IRS 990 table names (defaults to
  [`get_table_names()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_table_names.md)
  if not supplied).

- ccf:

  Data frame. Concordance crosswalk used for variable alignment.

- table_headers:

  Data frame. Output of
  [`get_table_headers()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_table_headers.md),
  providing schema details for relational table construction.

- output:

  One of `"csv"` (default, unchanged behaviour), `"parquet"`, or
  `"both"`. Passed through to
  [`build_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_table.md)
  and
  [`build_rdb_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_rdb_table.md),
  which write both formats from one materialised temp table.

- ...:

  Further arguments passed to
  [`write_table_output()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_table_output.md).

## Value

Invisibly, a character vector of the files written into `wd/CSV`.

## Details

The working directory (`wd`) should contain subdirectories named for
each tax year, and each of those subdirectories must include a DuckDB
file such as "EFILE2024.duckdb". The function calls helper functions
like
[`build_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_table.md)
and
[`build_rdb_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_rdb_table.md)
to populate these databases.

## Examples

``` r
if (FALSE) { # \dontrun{
extract_csv_tables(
  wd = "C:/Users/jdlec/DATA/DUCKDB_2025",
  years = 2009:2024
)

# publish both formats in one pass over the databases
extract_csv_tables(
  wd     = "C:/Users/jdlec/DATA/DUCKDB_2025",
  years  = 2009:2024,
  output = "both"
)
} # }
```
