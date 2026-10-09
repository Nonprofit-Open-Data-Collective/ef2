# Load the full IRS 990 e-filer index from the Data Commons

Downloads the most recent "all years" IRS 990 e-file index published to
the Giving Tuesday Data Commons and returns it as a `data.table`. This
is the complete index of every available filing.

## Usage

``` r
get_current_index_full(TIMEOUT = 600)
```

## Arguments

- TIMEOUT:

  Integer. Download timeout in seconds (default 600).

## Value

A `data.table` with one row per filing. See
[index](https://nonprofit-open-data-collective.github.io/ef2/reference/index.md)
for the column definitions.

## Details

Locates the newest `index_all_years_...` CSV by walking backward from
today (see
[`find_current_index_full()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_current_index_full.md)),
downloads it, sorts by `ReturnTs`, and drops duplicate `URL`s (keeping
the most recent). A count of filings per `TaxYear` is printed as a side
effect.

## See also

[`get_current_index_batch()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_current_index_batch.md)
for the incremental "latest only" index;
[`find_current_index_full()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_current_index_full.md)
to resolve just the URL.

## Examples

``` r
if (FALSE) { # \dontrun{
df <- get_current_index_full()
} # }
```
