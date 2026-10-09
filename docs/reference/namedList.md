# Create a named list from its arguments

Constructs a list whose names are taken from the supplied argument
expressions. Empty or `NULL` elements are replaced with `NA`.

## Usage

``` r
namedList(...)
```

## Arguments

- ...:

  Arguments to include in the list.

## Value

A named list.

## Examples

``` r
namedList(a = 1, b = 2)
#> $`1`
#> [1] 1
#> 
#> $`2`
#> [1] 2
#> 
```
