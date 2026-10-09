# Find Most Recent Date

Finds the position of the most recent date in a vector of dates.

## Usage

``` r
find_most_recent_date(dates)
```

## Arguments

- dates:

  A character vector of dates in "YYYY-MM-DD" format.

## Value

An integer indicating the position of the most recent date.

## Examples

``` r
dates <- c( "2023-11-18", "2023-11-19", "2024-06-01" )
find_most_recent_date( dates )
#> [1] 3
```
