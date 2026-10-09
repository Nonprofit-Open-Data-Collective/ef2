# Print Table Structure

Prints the hierarchical structure of a table.

## Usage

``` r
print_table_str(table.name)
```

## Arguments

- table.name:

  A character string specifying the table name.

## Value

None. Prints the table structure to the console.

## Examples

``` r
print_table_str("F9-P03-T01-PROGRAMS-OTHER")
#>                                         levelName
#> 1  Return                                        
#> 2   °--ReturnData                                
#> 3       ¦--IRS990                                
#> 4       ¦   ¦--ActivityOther                     
#> 5       ¦   ¦   ¦--ActivityCode                  
#> 6       ¦   ¦   ¦--Description                   
#> 7       ¦   ¦   ¦--Expense                       
#> 8       ¦   ¦   ¦--Grants                        
#> 9       ¦   ¦   °--Revenue                       
#> 10      ¦   ¦--Form990PartIII                    
#> 11      ¦   ¦   °--ActivityOther                 
#> 12      ¦   ¦       ¦--ActivityCode              
#> 13      ¦   ¦       ¦--Description               
#> 14      ¦   ¦       ¦--Expense                   
#> 15      ¦   ¦       ¦--Grants                    
#> 16      ¦   ¦       °--Revenue                   
#> 17      ¦   ¦--ProgSrvcAccomActyOtherGrp         
#> 18      ¦   ¦   ¦--ActivityCd                    
#> 19      ¦   ¦   ¦--Desc                          
#> 20      ¦   ¦   ¦--ExpenseAmt                    
#> 21      ¦   ¦   ¦--GrantAmt                      
#> 22      ¦   ¦   °--RevenueAmt                    
#> 23      ¦   °--ProgramServiceAccomplishments     
#> 24      ¦       ¦--DescriptionProgramServiceAccom
#> 25      ¦       ¦--ProgramServiceExpenses        
#> 26      ¦       °--GrantsAndAllocations          
#> 27      °--IRS990EZ                              
#> 28          °--ProgSrvcAccomActyOtherGrp         
#> 29              ¦--ActivityCd                    
#> 30              ¦--Desc                          
#> 31              ¦--ExpenseAmt                    
#> 32              ¦--GrantAmt                      
#> 33              °--RevenueAmt                    
```
