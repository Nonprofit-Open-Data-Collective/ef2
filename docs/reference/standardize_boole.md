# Standardize boolean inputs

Converts various string representations of true/false (e.g. "YES", "X",
"1") into a logical vector. `NA` values are treated as `FALSE`.

## Usage

``` r
standardize_boole(x)
```

## Arguments

- x:

  A vector of values to standardize.

## Value

A logical vector.

## Examples

``` r
standardize_boole(c("YES", "NO", NA, "X"))
#> [1]  TRUE FALSE FALSE  TRUE
```
