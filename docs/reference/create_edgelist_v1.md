# Create Edgelist Version 1

Creates an edgelist from XPath expressions by splitting them into
hierarchical node pairs.

## Usage

``` r
create_edgelist_v1(xpaths)
```

## Arguments

- xpaths:

  A character vector of XPath expressions.

## Value

A data frame containing the edgelist with two columns representing
parent-child relationships.

## Examples

``` r
create_edgelist_v1(c("/A/B/C", "/A/D/E"))
#>   V1 V2
#> 1  A  B
#> 2  B  C
#> 3  A  D
#> 4  D  E
```
