# Build a DuckDB database from batches of XML filings (parallel safe)

Processes XML batches in parallel, with each worker writing to its own
DuckDB shard. When all workers complete, the shards are merged into a
unified database for the specified year.

## Usage

``` r
build_database(
  year,
  urls = NULL,
  group.size = 25,
  ccf = NULL,
  path = ".",
  is_update = FALSE,
  workers = NULL
)
```

## Arguments

- year:

  Integer. Year label for the database.

- urls:

  Optional character vector of XML URLs to process. If NULL, resumes
  from existing batch files in the year's folder.

- group.size:

  Integer batch size (default = 25).

- ccf:

  Concordance crosswalk object (optional).

- path:

  Directory in which to store year subfolder and database files.

- is_update:

  Logical; if TRUE, this is an incremental update build rather than a
  full-year rebuild.

- workers:

  Optional integer number of parallel worker processes. If NULL
  (default) uses the conservative `min(4, availableCores()/2)`. Because
  the work is network-bound (each worker mostly waits on XML downloads),
  setting this above the physical core count can substantially raise
  throughput for large jobs. Be considerate of the source S3 endpoint
  when raising it.

## Value

Invisibly returns the path to the merged DuckDB database.

## Details

Workers share one queue of batch files and claim the next batch when
they finish one (see
[`run_batch_queue()`](https://nonprofit-open-data-collective.github.io/ef2/reference/run_batch_queue.md)),
so a slow filing holds up one worker rather than every batch assigned to
it (EF2-20).

## Examples

``` r
if (FALSE) { # \dontrun{
build_database(2021, urls = urls, group.size = 25, path = "data")
build_database(2024, urls = urls, path = "data", workers = 10)
} # }
```
