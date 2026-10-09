# Extract Dates from Filenames

Extracts dates in "YYYY-MM-DD" format from a vector of strings.

## Usage

``` r
extract_dates(x)
```

## Arguments

- x:

  A character vector containing filenames.

## Value

A character vector of extracted dates.

## Examples

``` r
extract_dates("xmls_created_on_2023-11-19.csv")
#> [1] "2023-11-19"
```
