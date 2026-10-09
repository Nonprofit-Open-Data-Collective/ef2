# Find IRS-indexed filings missing from the GTDC index

Compares object IDs and returns the IRS index rows whose filing is not
in the GTDC index.

## Usage

``` r
diff_irs_gt(irs, gt)
```

## Arguments

- irs:

  Output of
  [`get_irs_index()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_irs_index.md).

- gt:

  A GTDC index, e.g. from
  [`get_current_index_full()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_current_index_full.md).
  Needs an `ObjectId` column, or a `URL` column the ID can be read from.

## Value

The subset of `irs`. A summary by `XML_BATCH_ID` is printed.
