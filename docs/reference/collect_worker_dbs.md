# Worker databases to merge for a year

This run's worker databases plus every other `worker_NN_<year>.duckdb`
in the year folder, so shards left by an interrupted run are merged too
(EF2-14).

## Usage

``` r
collect_worker_dbs(year_path, year, worker_dbs = character())
```

## Arguments

- year_path:

  Year folder.

- year:

  Year label used in the shard file names.

- worker_dbs:

  Worker databases returned by this run.

## Value

Character vector of paths, this run's first, without duplicates.
