# Write batch files to disk

Persists each element of a batch list as a standalone `.R` file
containing an object named `x`. This allows parallel workers to safely
read and process batches without contention for a shared `.RDS` file.

## Usage

``` r
write_batches(batchfile, path = ".")
```

## Arguments

- batchfile:

  Named list where each element contains a vector (e.g., URLs or
  filenames) to be processed in one batch.

- path:

  Directory in which to create the `batches/` subfolder. Defaults to the
  current working directory.

## Value

Invisibly returns `NULL`. Files are created as a side effect.

## Details

Each batch is written to a file named `batches/<batchname>.R` inside the
specified path. The function uses
[`purrr::iwalk()`](https://purrr.tidyverse.org/reference/imap.html) to
iterate over the list, ensuring the batch name and data stay paired
correctly.

## Examples

``` r
if (FALSE) { # \dontrun{
batches <- list(G01 = c("file1.xml", "file2.xml"),
                G02 = c("file3.xml", "file4.xml"))
write_batches(batches, path = "data/2021")
} # }
```
