# Write a DuckDB table to CSV on S3 via COPY

Retained for backward compatibility.
[`write_table_output()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_table_output.md)
supersedes this and can emit Parquet alongside the CSV from a single
materialised temp table.

## Usage

``` r
write_csv_to_s3(db_tbl, table_name, year, con)
```

## Arguments

- db_tbl:

  A lazy tibble / table reference.

- table_name:

  Character.

- year:

  Integer year.

- con:

  DBI connection.
