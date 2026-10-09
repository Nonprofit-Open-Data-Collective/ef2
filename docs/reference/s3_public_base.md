# S3 prefix that built tables are published to

Returns the `s3://` prefix used when `post_to_s3 = TRUE`. The default is
the value
[`write_csv_to_s3()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_csv_to_s3.md)
has always hard-coded, so behaviour is unchanged; override it with
`options( ef2.s3_public_base = "s3://nccs-efile/public/efile_v2_3/" )`
to publish to a different release prefix without editing the package.

## Usage

``` r
s3_public_base()
```

## Value

Character S3 prefix, with a trailing slash.
