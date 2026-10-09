# Check whether the packaged concordance is current

Compares the concordance shipped with the package (`data(concordance)`)
to the current master concordance file on GitHub, so a stale packaged
copy can be detected (e.g. at build/check time).

## Usage

``` r
concordance_is_current(verbose = TRUE)
```

## Arguments

- verbose:

  Logical; if TRUE (default) messages a short summary.

## Value

Logical `TRUE` if the packaged data matches GitHub, `FALSE` if it is out
of date, or `NA` (with a warning) if the GitHub version could not be
retrieved (e.g. offline).

## See also

[`update_concordance()`](https://nonprofit-open-data-collective.github.io/ef2/reference/update_concordance.md)
to refresh the packaged data.
