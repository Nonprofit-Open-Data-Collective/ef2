# Generate an ASCII Diagram of Functions and Arguments from R Scripts

Reads multiple R script files and generates an ASCII representation
listing each file, its contained functions, and their arguments.

## Usage

``` r
generate_ascii_diagram(files)
```

## Arguments

- files:

  A character vector of R script file paths.

## Value

Prints an ASCII diagram showing the functions and their arguments.

## Examples

``` r
if (FALSE) { # \dontrun{
generate_ascii_diagram(c("script1.R", "script2.R"))
} # }
```
