# Inspect a DuckDB database interactively

Lists all tables in a DuckDB file, showing their dimensions and sample
contents. If a specific table name is provided, previews the first `n`
rows from that table.

## Usage

``` r
inspect_ddb(db = "EFILE2021.duckdb", table = NULL, n = 25)
```

## Arguments

- db:

  Path to a DuckDB database file (default `"EFILE2021.duckdb"`).

- table:

  Optional. Name of a table to inspect. If `NULL` (default), shows all
  tables with their dimensions and first 10 rows.

- n:

  Integer. Number of rows to return when inspecting a specific table
  (default `25`).

## Value

Invisibly returns either:

- a list of table summaries (if `table = NULL`), or

- a data frame preview (if a table is specified)

## Examples

``` r
if (FALSE) { # \dontrun{
inspect_ddb("EFILE2021.duckdb")            # Overview of all tables
inspect_ddb("EFILE2021.duckdb", "FLATXML") # Preview first 25 rows
} # }
```
