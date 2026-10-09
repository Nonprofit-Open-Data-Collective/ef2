# Get URL Status

Retrieves the HTTP status of a given URL.

## Usage

``` r
get_url_status(url)
```

## Arguments

- url:

  A character string representing the URL to check.

## Value

A data frame containing the URL, its existence status, and the HTTP
status code.

## Examples

``` r
get_url_status("https://example.com")
#>                   url exists status
#> 1 https://example.com   TRUE    200
```
