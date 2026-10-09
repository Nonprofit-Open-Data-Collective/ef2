# Add KEYS columns to a flattened table

Add KEYS columns to a flattened table

## Usage

``` r
add_keys(db_tbl, table_name, year, cc_file, con)
```

## Arguments

- db_tbl:

  Lazy tibble (or data frame).

- table_name:

  Character table id.

- year:

  Integer year.

- cc_file:

  Concordance crosswalk data frame.

- con:

  DBI connection.

## Value

A tibble with KEYS columns relocated first.
