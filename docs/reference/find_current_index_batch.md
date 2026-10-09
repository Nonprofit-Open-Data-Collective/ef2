# Find Most Recent AWS Batch Index

Identifies the most recent AWS batch index file (only new files).

## Usage

``` r
find_current_index_batch(days = 100)
```

## Arguments

- days:

  An integer: days to probe in the fallback, and the age past which a
  stale index is reported.

## Value

A character string representing the URL of the most recent index file,
or NA if none found.

## Details

Lists the bucket anonymously
([`list_gt_indices()`](https://nonprofit-open-data-collective.github.io/ef2/reference/list_gt_indices.md));
if that fails, falls back to probing the last `days` days by date. See
[`find_current_index()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_current_index.md).

## Examples

``` r
find_current_index_batch(100)
#> [1] "https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_latest_only_efiledata_xmls_created_on_2026-08-25.csv"
```
