# Match IRS batch IDs to the zip files that hold them

A batch `YYYY_TEOS_XML_MMx` can be split across zips that share the
`YYYY_TEOS_XML_MM` stem (e.g. `05A` and `05B`). Matching is on that stem
and ignores case (the IRS used `2024_TEOS_XML_04a`).

## Usage

``` r
match_batch_zips(batches, zips)
```

## Arguments

- batches:

  Character vector of `XML_BATCH_ID` values.

- zips:

  Output of
  [`get_irs_zip_urls()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_irs_zip_urls.md).

## Value

The rows of `zips` that may contain the batches.
