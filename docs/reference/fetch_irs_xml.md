# Extract missing filings from the IRS zip files

For each zip that may hold the missing filings, downloads it, extracts
only the wanted `<OBJECT_ID>_public.xml` files into `dest`, and deletes
the zip.

## Usage

``` r
fetch_irs_xml(miss, dest, zips = NULL, zip_dir = tempdir(), keep_zips = FALSE)
```

## Arguments

- miss:

  Output of
  [`diff_irs_gt()`](https://nonprofit-open-data-collective.github.io/ef2/reference/diff_irs_gt.md).

- dest:

  Local folder for the XML files.

- zips:

  Output of
  [`get_irs_zip_urls()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_irs_zip_urls.md);
  read from the IRS page if `NULL`.

- zip_dir:

  Folder for the temporary zip downloads.

- keep_zips:

  Keep the downloaded zips (default `FALSE`).

## Value

A `data.frame` with `OBJECT_ID`, `ZIP_FILE` and `FILE` for every file
now in `dest`.

## Details

Files already in `dest` are not fetched again, so an interrupted run can
be restarted. Rows with no `XML_BATCH_ID` (index years before 2024)
cannot be mapped to a zip and are reported, not fetched.
