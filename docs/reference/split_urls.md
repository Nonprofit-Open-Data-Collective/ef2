# Split a URL vector into named groups and persist RDS

Split a URL vector into named groups and persist RDS

## Usage

``` r
split_urls(urls, group.size = 25, path = ".")
```

## Arguments

- urls:

  Character vector of URLs.

- group.size:

  Integer batch size.

- path:

  Directory in which to create the `batches/` subfolder.

## Value

Invisibly the batch list.
