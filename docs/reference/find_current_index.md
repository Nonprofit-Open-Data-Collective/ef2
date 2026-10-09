# Find Most Recent GTDC Index of a Given Type

Shared engine for
[`find_current_index_full()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_current_index_full.md)
and
[`find_current_index_batch()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_current_index_batch.md).

## Usage

``` r
find_current_index(type = c("full", "batch"), days = 100)
```

## Arguments

- type:

  `"full"` (all years) or `"batch"` (latest only).

- days:

  Days to probe in the fallback, and the age past which a stale index is
  reported.

## Value

The index URL, or `NA` if none was found.

## Details

Lists the bucket with
[`list_gt_indices()`](https://nonprofit-open-data-collective.github.io/ef2/reference/list_gt_indices.md)
and takes the newest matching CSV, however old it is. If the listing is
unavailable, falls back to probing one URL per day for the last `days`
days. A message reports the index date when it is older than `days`,
because the GTDC indices are not always refreshed (the newest was
2024-12-23 as of October 2026).
