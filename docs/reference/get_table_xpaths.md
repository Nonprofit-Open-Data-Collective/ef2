# Get Table XPaths

Retrieves the XPaths associated with a specific table name from the
concordance.

## Usage

``` r
get_table_xpaths(table.name = "F9-P07-T01-COMPENSATION")
```

## Arguments

- table.name:

  A character string specifying the table name.

## Value

A character vector of XPaths associated with the table name.

## Examples

``` r
get_table_xpaths("F9-P03-T01-PROGRAMS-OTHER")
#>  [1] "/Return/ReturnData/IRS990/ActivityOther/ActivityCode"                                  
#>  [2] "/Return/ReturnData/IRS990/Form990PartIII/ActivityOther/ActivityCode"                   
#>  [3] "/Return/ReturnData/IRS990/ProgSrvcAccomActyOtherGrp/ActivityCd"                        
#>  [4] "/Return/ReturnData/IRS990EZ/ProgSrvcAccomActyOtherGrp/Desc"                            
#>  [5] "/Return/ReturnData/IRS990/ActivityOther/Description"                                   
#>  [6] "/Return/ReturnData/IRS990/Form990PartIII/ActivityOther/Description"                    
#>  [7] "/Return/ReturnData/IRS990/ProgramServiceAccomplishments/DescriptionProgramServiceAccom"
#>  [8] "/Return/ReturnData/IRS990/ProgSrvcAccomActyOtherGrp/Desc"                              
#>  [9] "/Return/ReturnData/IRS990/ActivityOther/Expense"                                       
#> [10] "/Return/ReturnData/IRS990/Form990PartIII/ActivityOther/Expense"                        
#> [11] "/Return/ReturnData/IRS990/ProgramServiceAccomplishments/ProgramServiceExpenses"        
#> [12] "/Return/ReturnData/IRS990/ProgSrvcAccomActyOtherGrp/ExpenseAmt"                        
#> [13] "/Return/ReturnData/IRS990EZ/ProgSrvcAccomActyOtherGrp/GrantAmt"                        
#> [14] "/Return/ReturnData/IRS990/ActivityOther/Grants"                                        
#> [15] "/Return/ReturnData/IRS990/Form990PartIII/ActivityOther/Grants"                         
#> [16] "/Return/ReturnData/IRS990/ProgramServiceAccomplishments/GrantsAndAllocations"          
#> [17] "/Return/ReturnData/IRS990/ProgSrvcAccomActyOtherGrp/GrantAmt"                          
#> [18] "/Return/ReturnData/IRS990/ActivityOther/Revenue"                                       
#> [19] "/Return/ReturnData/IRS990/Form990PartIII/ActivityOther/Revenue"                        
#> [20] "/Return/ReturnData/IRS990/ProgSrvcAccomActyOtherGrp/RevenueAmt"                        
```
