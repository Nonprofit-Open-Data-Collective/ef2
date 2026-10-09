# Load pending batch files from disk

Reads all `.R` files from a `batches/` directory and reconstructs them
as a named list, where each element contains the object `x` defined
inside the file.

## Usage

``` r
gather_batches(path = ".")
```

## Arguments

- path:

  Directory containing a `batches/` subfolder. Defaults to the current
  working directory.

## Value

Named list of batch contents.

## Details

Each batch file is read in isolation using
[`sys.source()`](https://rdrr.io/r/base/sys.source.html) into a
temporary environment to avoid polluting the global environment. The
result is a list of batches, with names derived from the filenames
(minus the `.R` extension).

## Examples

``` r
if (FALSE) { # \dontrun{
batches <- gather_batches("data/2021")
names(batches)
} # }
```
