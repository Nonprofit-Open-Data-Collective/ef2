# Work through the shared batch queue

Called by each
[`build_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_database.md)
worker. Batch files in `batches/` form one queue for all workers: a
worker claims a batch by creating the directory `claimed/<batchname>`,
processes the batch, then deletes its batch file and the claim. Creating
a directory succeeds for exactly one worker, so each batch is processed
once, and a worker held up by a slow batch leaves the rest of the queue
to the others (EF2-20).

## Usage

``` r
run_batch_queue(
  batchnames,
  year_path,
  process,
  log_msg = function(...) invisible(NULL)
)
```

## Arguments

- batchnames:

  Batch names this run may claim, in claim order. Batch files in
  `batches/` that are not named here are left alone.

- year_path:

  Folder holding `batches/`.

- process:

  Function applied to each batch (the vector `x` from its file).

- log_msg:

  Logging function taking `...`.

## Value

Names of the batches this worker completed.

## Details

A batch file stays in `batches/` until its batch is done, so an
interrupted or failed batch is still there for a resumed run. A failed
batch keeps its claim, so no other worker retries it in the same run;
[`release_claimed_batches()`](https://nonprofit-open-data-collective.github.io/ef2/reference/release_claimed_batches.md)
clears the claims.

The claim is a directory rather than a renamed batch file: on Windows
two workers renaming the same file at once could both succeed.

Uses base R only, so a test can run it in plain worker sessions.
