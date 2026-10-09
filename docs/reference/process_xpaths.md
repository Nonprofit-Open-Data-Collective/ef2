# Combine and Process Multi-Year XPATH Reports

The `process_xpaths()` function automates the full workflow of
generating, combining, and summarizing XPATH usage reports across
multiple DuckDB databases. It can process multiple tax years, merge the
resulting reports, summarize schema versions, and add derived metadata
such as first/last year and current version indicators.

## Usage

``` r
process_xpaths(years, base_path, concordance = NULL, get_type = NULL)
```

## Arguments

- years:

  Numeric vector of tax years to process.

- base_path:

  Character. Base path containing yearly DuckDB folders and the
  `xpath_reports` directory.

- concordance:

  Optional data frame containing a variable `xpath` for merging. If not
  supplied, the merge step is skipped.

- get_type:

  Optional function that accepts an XPATH string and returns a type
  label. Used to classify paths into `"HEADER"` or `"DATA"`.

## Value

Invisibly returns a data frame containing all combined and processed
XPATHs.

## Details

This function:

1.  Iterates over a range of tax years and calls
    [`generate_xpath_report()`](https://nonprofit-open-data-collective.github.io/ef2/reference/generate_xpath_report.md)
    for each.

2.  Reads all CSV reports from the specified `xpath_reports` directory.

3.  Combines and aggregates XPATH occurrences across years.

4.  Cleans and consolidates schema version lists using
    [`combine_lists()`](https://nonprofit-open-data-collective.github.io/ef2/reference/combine_lists.md).

5.  Extracts first and last schema years and merges results with a
    `concordance` table if provided.

The final combined report is saved to `"xpath_reports/ALL-XPATHS.csv"`.

## Examples

``` r
if (FALSE) { # \dontrun{
process_xpaths(
  years = 2009:2024,
  base_path = "C:/Users/jdlec/DATA/DUCKDB_2025",
  concordance = concordance,
  get_type = get_type
)
} # }
```
