# Summarize the attribute schema from a tidy ATTRIBUTES table

Provides a summary of attribute usage in a tidy `ATTRIBUTES` table,
reporting the number of occurrences, unique OBJECTIDs, and example
values.

## Usage

``` r
summarize_attr_schema(attr_df)
```

## Arguments

- attr_df:

  Data frame produced by
  [`get_attr_df()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_attr_df.md).

## Value

A data frame with one row per attribute, including:

- `attr_name` - attribute name

- `n_records` - total number of rows containing it

- `n_objects` - distinct OBJECTIDs it appears in

- `n_unique_vals` - number of distinct values observed

- `example_value` - representative example value

## Examples

``` r
if (FALSE) { # \dontrun{
attrs <- get_attr_df("data/2021/EFILE2021.duckdb")
summarize_attr_schema(attrs)
} # }
```
