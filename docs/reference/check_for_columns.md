# Ensure destination DuckDB table has all required columns

Adds any missing columns (as TEXT) needed to append `new_data` into an
existing DuckDB table.

## Usage

``` r
check_for_columns(new_data, table_name, con)
```

## Arguments

- new_data:

  Data frame with new data to append.

- table_name:

  Character table name.

- con:

  DBI connection to DuckDB.
