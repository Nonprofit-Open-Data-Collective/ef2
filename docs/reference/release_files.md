# List the Parquet tables of a release

Lists `<TABLE>-<YEAR>.parquet` files in a local folder or an S3 prefix
of the public NCCS bucket.

## Usage

``` r
release_files(path)
```

## Arguments

- path:

  A local folder, an `s3://bucket/prefix/` URI, or a bare prefix of the
  NCCS bucket such as `"public/efile_v3_1/"`. S3 prefixes are listed
  anonymously over HTTPS.

## Value

A `data.table` with `table`, `year` and `file` (a path or HTTPS URL
DuckDB can read).
