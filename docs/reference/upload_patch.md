# Upload patch XML files and index to the NCCS bucket

Copies every `*_public.xml` and `PATCH-INDEX-*.csv` in `dir` to
`s3://nccs-efile/xml2/<build>_patch/`, skipping files already there.

## Usage

``` r
upload_patch(dir, build, bucket = "nccs-efile", dry_run = TRUE, workers = 8)
```

## Arguments

- dir:

  Local folder from
  [`fetch_irs_xml()`](https://nonprofit-open-data-collective.github.io/ef2/reference/fetch_irs_xml.md)
  /
  [`build_patch_index()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_patch_index.md).

- build:

  Build name, e.g. `"v2_3"`.

- bucket:

  S3 bucket (default `"nccs-efile"`).

- dry_run:

  If `TRUE` (default), report what would be uploaded and stop.

- workers:

  Parallel uploads.

## Value

A `data.frame` of files and upload status, invisibly.

## Details

Uses
[`aws.s3::put_object()`](https://rdrr.io/pkg/aws.s3/man/put_object.html),
which finds credentials with
[`aws.signature::locate_credentials()`](https://rdrr.io/pkg/aws.signature/man/locate_credentials.html):
environment variables, `~/.aws/credentials`, or `.Renviron`. The bucket
is public, so the uploaded files are publicly readable.
