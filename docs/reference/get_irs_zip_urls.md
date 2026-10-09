# List the IRS bulk-download zip files

Reads the IRS "Form 990 series downloads" page and returns the links to
the XML zip files.

## Usage

``` r
get_irs_zip_urls(
  years = NULL,
  page = "https://www.irs.gov/charities-non-profits/form-990-series-downloads"
)
```

## Arguments

- years:

  Optional integer vector; keep only zips for these index years.

- page:

  URL of the downloads page.

## Value

A `data.frame` with columns `year`, `zip` (file name without `.zip`),
and `url`.

## Details

A batch can span several zips: the IRS index labels both halves of May
2026 `2026_TEOS_XML_05A`, but the second half is in
`2026_TEOS_XML_05B.zip`. Use
[`match_batch_zips()`](https://nonprofit-open-data-collective.github.io/ef2/reference/match_batch_zips.md)
to map batches to zips.

## Examples

``` r
if (FALSE) { # \dontrun{
get_irs_zip_urls( 2025:2026 )
} # }
```
