# Validate URL Status

Checks if a given URL is valid by sending an HTTP HEAD request.

## Usage

``` r
url_is_valid(url)
```

## Arguments

- url:

  A character string representing the URL to validate.

## Value

A logical value indicating if the URL is valid (HTTP status 200).

## Examples

``` r
base <- "https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/"
fn_01 <- "index_all_years_efiledata_xmls_created_on_2024-12-23.csv"
fn_02 <- "index_all_years_efiledata_xmls_created_on_2024-12-24.csv"
url_01 <- paste0( base, fn_01 )  
url_02 <- paste0( base, fn_02 )  
url_is_valid( url_01 )   # file exists
#> [1] TRUE
url_is_valid( url_02 )   # file does not exist
#> [1] FALSE
```
