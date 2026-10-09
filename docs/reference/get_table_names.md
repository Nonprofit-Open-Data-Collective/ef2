# Get RDB table names from the concordance file

Retrieves the unique relational-table names defined in the concordance
`rdb_table` field.

## Usage

``` r
get_table_names(exclude = c("T99"))
```

## Arguments

- exclude:

  Character vector of table-code substrings to drop (matched as
  `-<code>-`). Defaults to `c("T99")`, which removes the
  supplemental-info text tables.

## Value

A character vector of table names (e.g. `"F9-P01-T00-SUMMARY"`).

## Examples

``` r
if (FALSE) { # \dontrun{
get_table_names()
} # }
```
