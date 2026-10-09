# Open a DuckDB database connection with S3 support

Open a DuckDB database connection with S3 support

## Usage

``` r
open_database(
  s3_region = "us-east-1",
  s3_endpoint = "s3.amazonaws.com",
  anonymous = TRUE
)
```

## Arguments

- s3_region:

  AWS region (default "us-east-1").

- s3_endpoint:

  S3 endpoint domain (default "s3.amazonaws.com"). Use
  "s3.dualstack.us-east-1.amazonaws.com" for dualstack URLs.

- anonymous:

  Logical; TRUE for anonymous S3 access.

## Value

DBI connection object with httpfs configured for S3.
