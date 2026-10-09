# Write a built table to CSV and/or Parquet from a single DuckDB temp table

Materialises `db_tbl` into a DuckDB temporary table once, then `COPY`s
it to CSV, Parquet, or both. Writing both from the same materialised
relation is what makes the two outputs consistent: they are two
serialisations of one relation, not a text file plus a re-parse of that
text file.

## Usage

``` r
write_table_output(
  db_tbl,
  table_name,
  year,
  con,
  output = c("csv", "parquet", "both"),
  dest = "CSV/",
  normalize_empty = TRUE,
  sort_key = c("ORG_EIN", "OBJECTID", "TABLE_ID"),
  compression = "zstd",
  compression_level = 9L,
  row_group_size = 50000L,
  temp_name = "TEMP"
)
```

## Arguments

- db_tbl:

  A lazy tibble / table reference to materialise.

- table_name:

  Character table id, e.g. `"F9-P00-T00-HEADER"`.

- year:

  Integer year.

- con:

  DBI connection to DuckDB.

- output:

  One of `"csv"`, `"parquet"`, `"both"`.

- dest:

  Destination directory or `s3://` prefix. Defaults to `"CSV/"`, the
  path the package has always used.

- normalize_empty:

  Logical; collapse `''` to NULL in Parquet so it agrees with the CSV on
  read-back. See Details.

- sort_key:

  Columns to sort both outputs by, in order, or NULL. Keys the table
  lacks are skipped: `TABLE_ID` exists only on repeating-group tables.
  The default keeps each filing's rows together and its repeating groups
  in filing order, which `TABLE_ID`'s fixed width makes a plain text
  sort. Sorting also makes Parquet row-group min/max statistics
  selective and shrinks the file: TY2023 header went from 61.5 MB to
  56.2 MB sorted on `ORG_EIN`.

- compression:

  Parquet codec. `"zstd"` gives 61.5 MB against snappy's 109.7 MB on the
  TY2023 header table.

- compression_level:

  Integer zstd level.

- row_group_size:

  Rows per Parquet row group. 50,000 costs 2% in size over the 122,880
  default but cuts the rows scanned for a point lookup from 122,880 to
  51,200.

- temp_name:

  Name of the DuckDB temporary table to materialise into.

## Value

Invisibly, a character vector of the paths written.

## Details

**Why Parquet from the temp table and not from the CSV.** Everything in
FLATXML is stored as VARCHAR – `R/04_write_to_duckdb.R` calls
`lapply(df, as.character)` before writing – so the relation reaching
this function is already all-character. Copying it straight to Parquet
involves no type inference at any point. Converting the published CSV
instead means re-parsing text, and
[`data.table::fread()`](https://rdrr.io/pkg/data.table/man/fread.html)
and [`read.csv()`](https://rdrr.io/r/utils/read.table.html) both
silently cast `ORG_EIN` to integer: 7,969 of 20,000 sampled TY2023
header rows lose a leading zero that way, e.g. `061721946` becomes
`61721946`.

**The empty-string problem, and why `normalize_empty` defaults to
TRUE.** The relation genuinely holds two different blanks.
`pivot_wider(values_fill = "")` produces empty strings; the
`right_join()` against KEYS produces SQL NULLs. CSV writes these
differently – `""` against a bare empty field – but no reader
distinguishes them on the way back in. DuckDB, `readr` and `read.csv`
all return NA for both. Parquet has a real null indicator and so
preserves the distinction, which means a faithful Parquet file would
*not* agree with its own CSV sibling. In the TY2023 header table that is
roughly 12.2 million cells, about 29% of the file.

`normalize_empty = TRUE` collapses `''` to NULL in the Parquet output
only, reproducing what every CSV reader already does, so the two
published formats answer identically. The CSV cells are written as they
are. Set `normalize_empty = FALSE` to keep the distinction, but only
alongside a documented note that the two formats differ by design.
