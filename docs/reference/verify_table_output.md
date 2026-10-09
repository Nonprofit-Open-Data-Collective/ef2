# Verify that two serialisations of a table hold identical data

Compares a CSV and a Parquet file cell for cell without assuming either
has a unique key. Both are read all-VARCHAR, every row is hashed, and
the hashes are aggregated in sorted order, so the digest is independent
of row order and of ties.

## Usage

``` r
verify_table_output(csv_path, parquet_path, con, fold_empty = TRUE)
```

## Arguments

- csv_path:

  Path or URL to the CSV.

- parquet_path:

  Path or URL to the Parquet file.

- con:

  DBI connection to DuckDB.

- fold_empty:

  Logical; treat `''` and NULL as equal on both sides.

## Value

A one-row data frame: row counts, column counts, digests, and `ok`.

## Details

Ordering by `OBJECTID` is not sufficient for a whole-table digest. In
`F9-P07-T02-CONTRACTORS-2023` there are 299,205 rows but only 215,278
distinct `OBJECTID` values, so any `ORDER BY OBJECTID` aggregate is
non-deterministic among ties and reports a spurious mismatch. Hashing
rows and sorting the hashes removes the need for a key at all.

`fold_empty = TRUE` compares the CSV as every reader actually sees it,
which is the behaviour `normalize_empty = TRUE` in
[`write_table_output()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_table_output.md)
targets.
