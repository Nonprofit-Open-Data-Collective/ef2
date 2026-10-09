# Generate an XPATH Summary Report from a DuckDB Database

Connects to a DuckDB database containing IRS e-file XML tables and
produces a summary report of XPATH usage across filings. The report
includes:

- One row per unique `XPATH2` value from the `FLATXML` table

- A count of occurrences across all filings

- A concatenated list of unique XML schema versions from the `KEYS`
  table

## Usage

``` r
generate_xpath_report(
  year,
  base_path,
  output_dir = "xpath_reports",
  shutdown = TRUE
)
```

## Arguments

- year:

  Integer or character. Tax year of the database (used to locate the
  file and label the output CSV).

- base_path:

  Character. Base directory containing year-specific subfolders with the
  DuckDB database files (e.g., `EFILE2024.duckdb`).

- output_dir:

  Character. Directory where the CSV report will be written. Defaults to
  `"xpath_reports"`.

- shutdown:

  Logical. Whether to shut down DuckDB completely after disconnecting.
  Defaults to `TRUE`.

## Value

Invisibly returns a data frame with columns:

- xpath:

  Unique XPATH2 string

- count_occurrences:

  Number of occurrences in `FLATXML`

- count_filings:

  Number of distinct filings (`OBJECTID`) using the xpath

- schema_versions:

  Comma-separated list of distinct schema versions

## Details

The function performs an inner join between `FLATXML` and `KEYS` on
`OBJECTID` (after removing duplicate `(OBJECTID, VERSION)` pairs to
avoid Cartesian product inflation). It then aggregates results by
`XPATH2`.

The result is written to a CSV file in the specified `output_dir` and
returned (invisibly) as a data frame.

## Examples

``` r
if (FALSE) { # \dontrun{
generate_xpath_report(
  year = 2024,
  base_path = "C:/Users/jdlec/DATA/DUCKDB_2025"
)
} # }
```
