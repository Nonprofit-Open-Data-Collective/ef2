# Flatten a logical RDB table into wide format from FLATXML

Flatten a logical RDB table into wide format from FLATXML

## Usage

``` r
flatten_table(table_name, year, con)
```

## Arguments

- table_name:

  Character table identifier in the concordance.

- year:

  Integer year.

- con:

  DBI connection to DuckDB.

## Value

A lazy tibble (dbplyr) that can be `collect()`ed.
