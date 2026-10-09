# Concordance a published release was labelled with

New filings added to an archive must carry the same labels as the
filings already in it, or `FLATXML` ends up with two label sets and the
tables built from it have renamed and moved columns that do not line up.

## Usage

``` r
release_concordance(release)
```

## Arguments

- release:

  Release name, e.g. `"efile_v2_3"`.

## Value

A data frame with at least `xpath`, `variable_name`, `rdb_table`.

## Details

- `efile_v2_3`: the concordance recorded in the archives' `RELABEL_LOG`,
  concordance990 1.99.1 (commit 3af11bb),
  `concordance("v2", form = "F990")`, 7,016 rows. Shipped as
  `inst/extdata/concordance-efile_v2_3.csv.gz` (`xpath`,
  `variable_name`, `rdb_table`). Pinned rather than read from
  concordance990, because later releases of that package return a
  different concordance (2.0.1: 7,075 rows).

- `efile_v3_1`: concordance990 2.0.1 (commit 02de916),
  `concordance("v2", form = "F990")`, 7,075 rows. Shipped as
  `inst/extdata/concordance-efile_v3_1.csv.gz`.

- `efilepf_v3_1`: the same commit, `concordance("v2", form = "F990PF")`,
  2,524 rows. Shipped as `inst/extdata/concordance-efilepf_v3_1.csv.gz`.
  (v3_1 was labelled from these frozen snapshots; see EF2-18.)

- `efile_v2_0` to `efile_v2_2`, `NULL` or `""`:
  [`get_concordance()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_concordance.md),
  the master concordance those archives were built with.

- Anything else, e.g. `efilepf_v2_3`: an error. Pass `ccf` explicitly.
