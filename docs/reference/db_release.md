# Release recorded in a local archive's RELABEL_LOG

Release recorded in a local archive's RELABEL_LOG

## Usage

``` r
db_release(db_path)
```

## Arguments

- db_path:

  Path to a local `.duckdb` archive.

## Value

The most recent `RELABEL_LOG.release`, or `NULL` if the archive has no
`RELABEL_LOG` (archives built before efile_v2_3).
