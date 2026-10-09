# Build the patch index

Joins the IRS index rows of the missing filings to what
[`fetch_irs_xml()`](https://nonprofit-open-data-collective.github.io/ef2/reference/fetch_irs_xml.md)
extracted and to each file's return header, and writes the result to
`dest`.

## Usage

``` r
build_patch_index(miss, got, dest, build)
```

## Arguments

- miss:

  Output of
  [`diff_irs_gt()`](https://nonprofit-open-data-collective.github.io/ef2/reference/diff_irs_gt.md).

- got:

  Output of
  [`fetch_irs_xml()`](https://nonprofit-open-data-collective.github.io/ef2/reference/fetch_irs_xml.md).

- dest:

  Folder holding the extracted XML files; the index CSV is written there
  too.

- build:

  Build name, e.g. `"v2_3"`.

## Value

The patch index as a `data.table`, invisibly. Written to
`<dest>/PATCH-INDEX-<build>-<YYYY-MM-DD>.csv`.

## Details

The output has the IRS index columns, plus the columns a GTDC index has
that
[`update_db()`](https://nonprofit-open-data-collective.github.io/ef2/reference/update_db.md)
and
[`combine_index()`](https://nonprofit-open-data-collective.github.io/ef2/reference/combine_index.md)
use: `ObjectId`, `URL`, `TaxYear`, `FormType`. It also has `ZipFile`,
`PATCH_BUILD`, and `PATCH_CREATED`. Only filings whose XML was extracted
are included.
