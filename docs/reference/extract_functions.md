# Extract Function Names and Arguments from an R Script

Parses an R script to identify function definitions and their arguments.

## Usage

``` r
extract_functions(file)
```

## Arguments

- file:

  A character string specifying the path to an R script file.

## Value

A data frame containing function names and their respective arguments.

## Examples

``` r
if (FALSE) { # \dontrun{
extract_functions("script.R")
} # }
```
