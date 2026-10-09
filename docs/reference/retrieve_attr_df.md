# Retrieve attribute data from a DuckDB database

Queries the `ATTRIBUTES` table in a DuckDB database and returns a tidy
data frame with one row per XML node attribute.

## Usage

``` r
retrieve_attr_df(
  db,
  objectid = NULL,
  url = NULL,
  limit = Inf,
  read_only = TRUE
)
```

## Arguments

- db:

  Path to the DuckDB database file (e.g., `"EFILE2021.duckdb"`).

- objectid:

  Optional character vector of OBJECTIDs to filter by. If NULL
  (default), all records are returned.

- url:

  Optional character URL (used to derive OBJECTID automatically via
  [`get_object_id2()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_object_id2.md)).

- limit:

  Optional integer limit on number of rows (default Inf).

- read_only:

  Logical; open connection read-only for safety (default TRUE).

## Value

A tidy `data.frame` with columns:

- `OBJECTID`

- `node_name`

- `xpath`

- `attr_name`

- `attr_value`

## Examples

``` r
if (FALSE) { # \dontrun{
get_attr_df("data/2021/EFILE2021.duckdb")
get_attr_df("data/2021/EFILE2021.duckdb",
             objectid = "OID-202323179349200212")
get_attr_df("data/2021/EFILE2021.duckdb",
             url = "https://efile...202323179349200212_public.xml")
} # }
```
