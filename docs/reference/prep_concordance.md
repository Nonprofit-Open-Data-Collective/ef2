# Prepare a concordance crosswalk (uppercase colnames)

Prepare a concordance crosswalk (uppercase colnames)

## Usage

``` r
prep_concordance(ccf = NULL)
```

## Arguments

- ccf:

  Optional concordance; if NULL, loads via
  [`get_concordance()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_concordance.md).

## Value

Data frame with columns XPATH, VARIABLE_NAME, RDB_TABLE.
