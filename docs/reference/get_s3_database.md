# Attach an S3-hosted DuckDB database by filename

Attach an S3-hosted DuckDB database by filename

## Usage

``` r
get_s3_database(filename, version = NULL, anonymous = TRUE)
```

## Arguments

- filename:

  DuckDB filename within s3://nccs-efile/duckdb/.

- version:

  Optional S3 version subfolder under duckdb/ (e.g. "efile_v2_3").

- anonymous:

  Logical for anonymous access.

## Value

DBI connection with attached database.
