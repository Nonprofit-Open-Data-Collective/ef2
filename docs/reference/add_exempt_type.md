# Add `F9_00_ORG_EXEMPT_TYPE` to the 990 header table

Joins the status derived by
[`exempt_type_sql()`](https://nonprofit-open-data-collective.github.io/ef2/reference/exempt_type_sql.md)
onto the header table and places it after the `F9_00_EXEMPT_STAT_*`
checkboxes it summarises. It lives here rather than in `KEYS` so that
only `F9-P00-T00-HEADER` changes, and so that existing archives gain it
on a table rebuild, with no re-parse.

## Usage

``` r
add_exempt_type(db_tbl, year, con)
```

## Arguments

- db_tbl:

  Lazy tibble of the header table, with `OBJECTID`.

- year:

  Integer tax year.

- con:

  DBI connection.

## Value

`db_tbl` with `F9_00_ORG_EXEMPT_TYPE` added.
