# Summarize attribute structure from a DuckDB database

Convenience wrapper that reads the `ATTRIBUTES` table from a DuckDB
database and summarizes its contents using
[`summarize_attr_schema()`](https://nonprofit-open-data-collective.github.io/ef2/reference/summarize_attr_schema.md).
The result provides a compact overview of all attribute names, their
frequencies, and example values.

## Usage

``` r
summarize_attr_table(db_name)
```

## Arguments

- db_name:

  Path to a DuckDB database file (e.g., `"EFILE2021.duckdb"`).

## Value

A tidy `data.frame` summarizing attribute usage, typically including
columns such as:

- `attr_name` - the attribute name

- `n_records` - number of occurrences across all nodes

- `n_objects` - number of unique OBJECTIDs containing it

- `n_unique_vals` - number of distinct values observed

- `example_value` - representative example value

## See also

[`get_attr_df`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_attr_df.md),
[`summarize_attr_schema`](https://nonprofit-open-data-collective.github.io/ef2/reference/summarize_attr_schema.md)

## Examples

``` r
if (FALSE) { # \dontrun{
summarize_attr_table("data/2021/EFILE2021.duckdb")
} # }
```
