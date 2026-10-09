# Combine a GTDC index with a patch index

Stacks the two indices into one build index with one row per filing.
Where a filing is in both, the GTDC row is kept, so once GTDC catches up
the patch row drops out.

## Usage

``` r
combine_index(gt, patch, cols = c("ObjectId", "URL", "TaxYear", "FormType"))
```

## Arguments

- gt:

  A GTDC index (e.g.
  [`get_current_index_full()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_current_index_full.md)
  or the batch index).

- patch:

  Output of
  [`build_patch_index()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_patch_index.md),
  or the patch index CSV read back with all columns as character.

- cols:

  Columns to keep; must exist in both inputs.

## Value

A `data.table` with `cols` plus `SOURCE` (`"GTDC"` or `"PATCH"`).
