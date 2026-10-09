# Load the most recent IRS 990 e-filer batch index from the Data Commons

Downloads the most recent "latest only" IRS 990 e-file index published
to the Giving Tuesday Data Commons and returns it as a `data.table`.
Unlike
[`get_current_index_full()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_current_index_full.md),
this contains only the filings that are new to the most recent batch.

## Usage

``` r
get_current_index_batch(TIMEOUT = 600)
```

## Arguments

- TIMEOUT:

  Integer. Download timeout in seconds (default 600).

## Value

A `data.table` with one row per filing. See
[index](https://nonprofit-open-data-collective.github.io/ef2/reference/index.md)
for the column definitions.

## Details

Locates the newest `index_latest_only_...` CSV by walking backward from
today (see
[`find_current_index_batch()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_current_index_batch.md)),
downloads it, sorts by `ReturnTs`, and drops duplicate `URL`s (keeping
the most recent). A count of filings per `TaxYear` is printed as a side
effect.

## See also

[`get_current_index_full()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_current_index_full.md)
for the complete all-years index;
[`find_current_index_batch()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_current_index_batch.md)
to resolve just the URL.

## Examples

``` r
if (FALSE) { # \dontrun{
df <- get_current_index_batch()
} # }
```
