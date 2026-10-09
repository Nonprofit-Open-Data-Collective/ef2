# Check that a built database holds each filing once

Stops if `KEYS` has more rows than distinct `OBJECTID`s: a filing stored
twice is repeated in every table built from the database (EF2-19).
[`build_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_database.md)
calls it after the merge.

## Usage

``` r
check_unique_keys(db)
```

## Arguments

- db:

  Path to a DuckDB database with a `KEYS` table.

## Value

Invisibly, the number of filings (0 if there is no `KEYS` table).
