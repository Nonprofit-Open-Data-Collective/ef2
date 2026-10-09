# Get table headers

Returns a named list mapping one-to-many table identifiers (e.g.
`F9-P03-T01-PROGRAMS-OTHER`) to the character vectors of candidate XML
paths used to locate that table's repeating group across IRS schema
versions.

## Usage

``` r
get_table_headers()
```

## Value

A named list. Names are table header identifiers; values are character
vectors of XML paths for data extraction.

## Examples

``` r
headers <- get_table_headers()
headers$`F9-P03-T01-PROGRAMS-OTHER`
#> [1] "//IRS990/ActivityOther"                
#> [2] "//Form990PartIII/ActivityOther"        
#> [3] "//IRS990/ProgramServiceAccomplishments"
#> [4] "//IRS990/ProgSrvcAccomActyOtherGrp"    
#> [5] "//IRS990EZ/ProgSrvcAccomActyOtherGrp"  
```
