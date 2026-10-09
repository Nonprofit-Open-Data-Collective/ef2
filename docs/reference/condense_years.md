# Collapse years into ranges

Collapse years into ranges

## Usage

``` r
condense_years(y)
```

## Arguments

- y:

  Integer years.

## Value

A string such as `"2009-2011, 2013"`.

## Examples

``` r
condense_years( c( 2009, 2010, 2011, 2013 ) )
#> [1] "2009-2011, 2013"
```
