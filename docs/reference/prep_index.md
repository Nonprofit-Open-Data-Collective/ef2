# Prepare an index for batching

Filters an efiler index to the requested tax years and form types, and
removes duplicate filings (by URL). Ported from the `irs990efile`
package.

## Usage

``` r
prep_index(years = NULL, index, form.type = c("990", "990EZ"))
```

## Arguments

- years:

  Optional vector of tax years to keep. If NULL, all years in `index`
  are used.

- index:

  Data frame with at least `TaxYear`, `FormType`, and `URL` columns.

- form.type:

  Character vector of form types to keep (default `c("990", "990EZ")`).

## Value

A filtered, de-duplicated copy of `index`.
