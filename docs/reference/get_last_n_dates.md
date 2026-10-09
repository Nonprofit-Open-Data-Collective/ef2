# Get Last N Dates

Generates a sequence of the last N dates in "YYYY-MM-DD" format.

## Usage

``` r
get_last_n_dates(N = 30)
```

## Arguments

- N:

  An integer specifying the number of days to generate.

## Value

A character vector of dates in "YYYY-MM-DD" format.

## Examples

``` r
get_last_n_dates(30)
#>  [1] "2026-10-09" "2026-10-08" "2026-10-07" "2026-10-06" "2026-10-05"
#>  [6] "2026-10-04" "2026-10-03" "2026-10-02" "2026-10-01" "2026-09-30"
#> [11] "2026-09-29" "2026-09-28" "2026-09-27" "2026-09-26" "2026-09-25"
#> [16] "2026-09-24" "2026-09-23" "2026-09-22" "2026-09-21" "2026-09-20"
#> [21] "2026-09-19" "2026-09-18" "2026-09-17" "2026-09-16" "2026-09-15"
#> [26] "2026-09-14" "2026-09-13" "2026-09-12" "2026-09-11" "2026-09-10"
```
