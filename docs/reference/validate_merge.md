# Validate a merged DuckDB database against its worker sources

Compares table structures and row counts between a main merged DuckDB
and the worker databases it was built from. Each table's row counts from
all workers are summed and compared with the main database total.

## Usage

``` r
validate_merge(main_db, worker_dbs)
```

## Arguments

- main_db:

  Path to the main DuckDB database (e.g. `"EFILE2021.duckdb"`).

- worker_dbs:

  Character vector of worker database file paths (e.g. all
  `worker_XX_YYYY.duckdb` files).

## Value

A tibble summarizing row counts for each table:

- `table_name` - table name

- `main_rows` - number of rows in the merged database

- `worker_sum` - total rows across all workers

- `n_workers` - number of workers containing that table

- `match` - TRUE/FALSE indicating if totals match

## Examples

``` r
if (FALSE) { # \dontrun{
validate_merge("EFILE2021.duckdb",
               list.files("2021", pattern = "worker_.*\\.duckdb$", full.names = TRUE))
} # }
```
