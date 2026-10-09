# List Index Files in the GTDC S3 Bucket

Lists every file under `Indices/990xmls/` in the Giving Tuesday Data
Commons bucket with a plain HTTPS request. No AWS account, key, or CLI
is needed: the bucket allows anonymous listing.

## Usage

``` r
list_gt_indices(timeout = 30)
```

## Arguments

- timeout:

  Seconds to wait for each listing request.

## Value

A character vector of object keys (e.g.
`"Indices/990xmls/index_all_years_efiledata_xmls_created_on_2024-12-23.csv"`),
or `NULL` if the bucket could not be listed.

## Details

Follows S3 continuation tokens, so the result is complete even past
1,000 files. Returns `NULL` (rather than an error) if the listing is
refused or unreachable – e.g. if the bucket stops allowing anonymous
listing – so callers can fall back to probing URLs by date.

## Examples

``` r
if (FALSE) { # \dontrun{
keys <- list_gt_indices()
extract_filenames_full( keys )
} # }
```
