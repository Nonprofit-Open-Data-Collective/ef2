# Remove a processed batch file

Deletes the `.R` file corresponding to a processed batch, typically
after successful import into the database. This allows the build process
to resume later without reprocessing completed batches.

## Usage

``` r
remove_batch(batchname, path)
```

## Arguments

- batchname:

  Character. Name of the batch (e.g., `"G01{25}"`).

- path:

  Directory containing the `batches/` subfolder.

## Value

Invisibly returns `TRUE` if the file was removed successfully, otherwise
`FALSE`.

## Examples

``` r
if (FALSE) { # \dontrun{
remove_batch("G01{25}", path = "data/2021")
} # }
```
