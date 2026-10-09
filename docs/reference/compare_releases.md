# Compare two releases of the published tables

Reports what changed between two releases: tables added and dropped,
rows and columns per table and year, columns added and removed, filings
per tax year, and (given both concordances) label changes. Use
[`write_release_notes()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_release_notes.md)
to render the result.

## Usage

``` r
compare_releases(
  old,
  new,
  old_concordance = NULL,
  new_concordance = NULL,
  filings = TRUE,
  labels = c(old, new)
)
```

## Arguments

- old, new:

  Releases: local folders, `s3://` URIs, or bare prefixes of the NCCS
  bucket (e.g. `"public/efile_v2_3/"`).

- old_concordance, new_concordance:

  Optional data frames with `xpath`, `variable_name` and `rdb_table`
  (and optionally `multi_value`), e.g. from
  `concordance990::concordance("v2", form = "F990")`. Both are needed
  for the `labels` component.

- filings:

  Count filings per year and return type from the header tables.

- labels:

  Display names for the two releases (default: the paths).

## Value

A list of class `release_comparison` with `meta`, `tables`, `dims`,
`columns`, `filings` and `labels`.

## Details

Row and column counts come from Parquet metadata, so they are cheap even
over S3. Filing counts scan each year's header table
(`F9-P00-T00-HEADER`) and are skipped with `filings = FALSE`.

The comparison reports *what* changed, not why. Context such as which
filings were added and where they came from belongs in the `notes`
argument of
[`write_release_notes()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_release_notes.md).
