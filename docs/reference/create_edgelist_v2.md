# Create Edgelist Version 2

Similar to create_edgelist_v1 but removes the prefixes
"Return/ReturnData" from XPath expressions.

## Usage

``` r
create_edgelist_v2(xpaths)
```

## Arguments

- xpaths:

  A character vector of XPath expressions.

## Value

A data frame containing the edgelist with two columns representing
parent-child relationships.

## Examples

``` r
create_edgelist_v2(c("/Return/ReturnData/A/B", "/Return/ReturnData/C/D"))
#>   V1 V2
#> 1  A  B
#> 2  C  D
```
