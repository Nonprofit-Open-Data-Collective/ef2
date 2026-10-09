# Refresh the packaged concordance from GitHub

Package-maintenance helper that replaces the packaged `concordance`
dataset (`data/concordance.rda`) with the most up-to-date master
concordance file from GitHub.

## Usage

``` r
update_concordance(raw_copy = TRUE)
```

## Arguments

- raw_copy:

  Logical; if TRUE (default) also refresh the raw CSV at
  `inst/extdata/concordance.csv`.

## Value

Invisibly, the refreshed concordance as a `data.table`.

## Details

Downloads the master concordance CSV, normalizes column names to lower
case, optionally refreshes the raw copy at
`inst/extdata/concordance.csv`, and writes the compressed
`data/concordance.rda` via
[`usethis::use_data()`](https://usethis.r-lib.org/reference/use_data.html).
Run this from the package source root during development, then
rebuild/reinstall the package to pick up the new data. Requires the
`usethis` package.

## See also

[`get_concordance()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_concordance.md)
to load the concordance at run time.
