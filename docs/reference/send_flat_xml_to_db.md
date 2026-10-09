# Write flattened XML batch results to an existing DuckDB connection

Write flattened XML batch results to an existing DuckDB connection

## Usage

``` r
send_flat_xml_to_db(RESULTS, con)
```

## Arguments

- RESULTS:

  List of parsed XML outputs from
  [`get_flat_xml()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_flat_xml.md).

- con:

  Active DBI connection to DuckDB (persistent).

## Value

Invisibly TRUE on success.
