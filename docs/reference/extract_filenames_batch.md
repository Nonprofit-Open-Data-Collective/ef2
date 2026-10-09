# Extract Batch Index Filenames

Extracts batch index filenames from the list of all files in the GTDC
AWS S3 index bucket.

## Usage

``` r
extract_filenames_batch(strings)
```

## Arguments

- strings:

  A character vector containing strings to search.

## Value

A character vector of matched filenames.

## Examples

``` r
if (FALSE) { # \dontrun{
index.list <- get_index_list_awscli()
extract_filenames_batch( index.list )
} # }
```
