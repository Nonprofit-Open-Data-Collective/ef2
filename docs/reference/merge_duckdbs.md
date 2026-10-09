# Merge multiple worker DuckDB databases into a main database

This function combines tables (ATTRIBUTES, FLATXML, KEYS) from multiple
worker databases into a single main DuckDB database. It aligns schemas,
handles transactions, and logs merge details.

## Usage

``` r
merge_duckdbs(
  main_db,
  worker_dbs,
  overwrite = FALSE,
  cleanup = FALSE,
  skip_existing = FALSE
)
```

## Arguments

- main_db:

  Path to the output DuckDB database (will be created if missing).

- worker_dbs:

  Character vector of worker database file paths.

- overwrite:

  Logical; if TRUE, deletes existing main database before merging.

- cleanup:

  Logical; if TRUE, deletes worker databases after merging.

- skip_existing:

  Logical; if TRUE, rows of filings (by `OBJECTID`) already in the main
  database's `KEYS` are not copied again, so merging a shard twice, or
  one that was merged in part, adds no duplicates (EF2-14). Default
  FALSE keeps the original append-everything behaviour.

## Value

Invisibly returns the path to the merged database.
