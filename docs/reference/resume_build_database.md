# Resume a partial DuckDB build

Resumes an interrupted build by gathering remaining batch files in the
year's `batches/` folder and calling
[`build_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_database.md)
to process only those batches. Existing worker databases are reused and
appended to if present.

## Usage

``` r
resume_build_database(year, ccf = NULL, path = ".")
```

## Arguments

- year:

  Integer. Data year (subdirectory name).

- ccf:

  Concordance crosswalk, prepared via
  [`prep_concordance()`](https://nonprofit-open-data-collective.github.io/ef2/reference/prep_concordance.md).

- path:

  Project directory containing the year subfolder.

## Value

Invisibly returns the path to the merged DuckDB database.

## Examples

``` r
if (FALSE) { # \dontrun{
resume_build_database(2021, path = "data")
} # }
```
