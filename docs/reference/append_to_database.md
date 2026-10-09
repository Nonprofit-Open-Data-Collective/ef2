# Append a temporary DuckDB (new filings) into an existing local DuckDB

Inserts the rows from a temporary "update" database (built by
[`build_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_database.md)
with `is_update = TRUE`) into a base database in place, aligning
schemas. This is the local counterpart of
[`merge_databases()`](https://nonprofit-open-data-collective.github.io/ef2/reference/merge_databases.md):
pair it with
[`download_s3_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/download_s3_database.md)
to update a large archive without streaming the whole thing through
`httpfs`.

## Usage

``` r
append_to_database(
  target_db,
  temp_db_path,
  tables = base::c("KEYS", "FLATXML", "ATTRIBUTES")
)
```

## Arguments

- target_db:

  Path to the base DuckDB to append into (modified in place).

- temp_db_path:

  Path to the temporary DuckDB with the new filings.

- tables:

  Character vector of tables to append (default
  `c("KEYS", "FLATXML", "ATTRIBUTES")`).

## Value

Invisibly, `target_db`.
