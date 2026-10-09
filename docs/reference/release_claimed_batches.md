# Clear batch claims left by an earlier run

Removes the claims in `claimed/` held by batches that errored, or that a
worker was processing when a run was interrupted. Their batch files are
still in `batches/`, so once the claims are gone the next run picks them
up (EF2-20).

## Usage

``` r
release_claimed_batches(year_path)
```

## Arguments

- year_path:

  Folder holding `batches/` and `claimed/`.

## Value

Invisibly, the number of claims cleared.
