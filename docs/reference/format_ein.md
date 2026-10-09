# Format Employer Identification Numbers (EINs)

Converts between numeric EINs (e.g., `"123456789"`) and standardized
ID-style EINs (e.g., `"EIN-12-3456789"`).

This utility ensures EINs are properly zero-padded to nine digits and
formatted consistently for joining or matching across datasets.

## Usage

``` r
format_ein(x, to = "id")
```

## Arguments

- x:

  Character or numeric vector of EINs. Can contain mixed formats (e.g.,
  `"123456789"`, `"EIN-12-3456789"`, or `"12-3456789"`).

- to:

  Character. Direction of formatting:

  `"id"`

  :   Convert to standardized EIN ID format (`"EIN-XX-XXXXXXX"`).

  `"n"`

  :   Convert to numeric-only form (digits only, no punctuation or
      prefix).

## Value

A character vector of reformatted EINs.

## Examples

``` r
# Convert to EIN ID format
format_ein(c("123456789", "987654321"), to = "id")
#> [1] "EIN-12-3456789" "EIN-98-7654321"
#> [1] "EIN-12-3456789" "EIN-98-7654321"

# Convert back to numeric-only
format_ein(c("EIN-12-3456789", "EIN-98-7654321"), to = "n")
#> [1] "123456789" "987654321"
#> [1] "123456789" "987654321"
```
