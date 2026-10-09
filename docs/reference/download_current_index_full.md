# Download Current AWS Index

Downloads the most recent AWS index file.

## Usage

``` r
download_current_index_full()
```

## Value

None. Downloads the file as "INDEX.CSV" in the working directory.

## Examples

``` r
if (FALSE) { # \dontrun{
fn <- download_current_index_full()
index <- data.table::fread( fn )
split_index( index )
} # }
```
