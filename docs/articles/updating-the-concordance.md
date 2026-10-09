# Updating the Concordance for IRS Schema Changes

## Overview

The
[concordance](https://nonprofit-open-data-collective.github.io/ef2/reference/concordance.md)
is the crosswalk that maps every XML XPath to a standardized variable
name and relational table. But the IRS revises the 990 schema over time
— it adds lines, renames nodes, and introduces new schedules. When that
happens, filings contain XPaths the concordance has never seen, and
those fields silently fall through to the raw-node-name fallback (see
[Flattening IRS 990 e-file
XML](https://nonprofit-open-data-collective.github.io/ef2/articles/flatten-xmls.md)).

Keeping the concordance current is a two-part job:

1.  **Discover** which XPaths actually appear in the processed data, and
    which of them are *not yet* in the concordance —
    [`generate_xpath_report()`](https://nonprofit-open-data-collective.github.io/ef2/reference/generate_xpath_report.md)
    and
    [`process_xpaths()`](https://nonprofit-open-data-collective.github.io/ef2/reference/process_xpaths.md).
2.  **Refresh** the packaged copy once the master concordance has been
    extended —
    [`update_concordance()`](https://nonprofit-open-data-collective.github.io/ef2/reference/update_concordance.md)
    and
    [`concordance_is_current()`](https://nonprofit-open-data-collective.github.io/ef2/reference/concordance_is_current.md)
    (covered at the end).

## A miniature database to report on

[`generate_xpath_report()`](https://nonprofit-open-data-collective.github.io/ef2/reference/generate_xpath_report.md)
reads a built `EFILE<year>.duckdb` database (its `FLATXML` and `KEYS`
tables). For this article we stand up a tiny one-filing database from
the sample shipped with the package, and — to simulate an IRS schema
change — inject one **new field the concordance doesn’t know about**:

``` r
library(ef2)
library(dplyr)
library(DBI)
library(duckdb)

url      <- "https://gt990datalake-rawdata.s3.amazonaws.com/EfileData/XmlFiles/202341529349301414_public.xml"
xml_file <- system.file("extdata", "sample_990.xml", package = "ef2")
doc <- xml2::read_xml(xml_file); xml2::xml_ns_strip(doc)

flat <- readRDS(system.file("extdata", "sample_flat.rds", package = "ef2"))
keys <- as.data.frame(get_keys(doc, url))

# Simulate a new IRS field not present in the concordance:
new_field <- flat[1, ]
new_field$XPATH  <- "/Return/ReturnData/IRS990/NewSchemaField2024Amt"
new_field$XPATH2 <- new_field$XPATH
new_field$TYPE   <- "terminal"
new_field$RDB_TABLE     <- ""
new_field$VARIABLE_NAME <- "NewSchemaField2024Amt"
flat <- rbind(flat, new_field)

# Write FLATXML + KEYS into base_path/<year>/EFILE<year>.duckdb
base_path <- file.path(tempdir(), "efile_db")
dir.create(file.path(base_path, "2023"), recursive = TRUE, showWarnings = FALSE)
con <- dbConnect(duckdb::duckdb(), file.path(base_path, "2023", "EFILE2023.duckdb"))
dbWriteTable(con, "FLATXML", flat)
dbWriteTable(con, "KEYS",    keys)
dbDisconnect(con, shutdown = TRUE)
```

## Step 1 — `generate_xpath_report()`

[`generate_xpath_report()`](https://nonprofit-open-data-collective.github.io/ef2/reference/generate_xpath_report.md)
produces a census of every distinct XPath in one year’s database: how
often it occurs, and which IRS schema versions it appears under.

``` r
report <- generate_xpath_report(year = 2023, base_path = base_path)

dim(report)
#> [1] 527   4
head(report, 6)
#>                                                                     xpath count_occurrences
#> 1                       /Return/ReturnData/IRS990ScheduleI/RecipientTable                83
#> 2          /Return/ReturnData/IRS990ScheduleI/RecipientTable/CashGrantAmt                83
#> 3        /Return/ReturnData/IRS990ScheduleI/RecipientTable/IRCSectionDesc                83
#> 4  /Return/ReturnData/IRS990ScheduleI/RecipientTable/NonCashAssistanceAmt                83
#> 5     /Return/ReturnData/IRS990ScheduleI/RecipientTable/PurposeOfGrantTxt                83
#> 6 /Return/ReturnData/IRS990ScheduleI/RecipientTable/RecipientBusinessName                83
#>   count_filings schema_versions
#> 1             1        2022v5.0
#> 2             1        2022v5.0
#> 3             1        2022v5.0
#> 4             1        2022v5.0
#> 5             1        2022v5.0
#> 6             1        2022v5.0
```

The columns are:

- **`xpath`** — the normalized path (`XPATH2`, indices stripped).
- **`count_occurrences`** — how many times it appears across all filings
  in the year. Repeating (one-to-many) fields have high counts: here the
  Schedule I grant fields occur 83 times, once per grant.
- **`schema_versions`** — the distinct IRS return-schema versions the
  field was seen under (e.g. `2022v5.0`). This is the fingerprint that
  reveals *when* a field was introduced or retired.

The report is also written to
`base_path/xpath_reports/2023-XPATH-REPORT.csv` for later aggregation.

## Step 2 — `process_xpaths()` across years

Running one report tells you what a single year contains.
[`process_xpaths()`](https://nonprofit-open-data-collective.github.io/ef2/reference/process_xpaths.md)
does the same across a **range of years**, then does the work that
actually maintains the concordance:

- calls
  [`generate_xpath_report()`](https://nonprofit-open-data-collective.github.io/ef2/reference/generate_xpath_report.md)
  for each year and reads back every CSV,
- aggregates occurrences and consolidates the schema-version lists,
- derives `first_year` / `last_year` / `current_version` for each XPath,
  and
- **merges the result against the concordance with `all = TRUE`**, so
  every XPath present in the data *or* the concordance ends up in one
  table.

``` r
data(concordance, package = "ef2")

allx <- process_xpaths(years = 2023, base_path = base_path, concordance = concordance)

dim(allx)
#> [1] 6954   30
```

That `all = TRUE` merge is the key: XPaths that appear in the **data but
not the concordance** come back with empty concordance columns
(`variable_name` is `NA`). Those are the schema additions you need to
map.

## Step 3 — Surfacing genuinely new fields

A raw list of unmapped XPaths is noisy — it includes structural
*container* nodes (parents like `...Grp` and `USAddress`) that were
never meant to be in the concordance, because only **leaf** nodes carry
data. Filter to leaves with
[`find_terminal_nodes()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_terminal_nodes.md)
(the same helper flattening uses) to isolate the real additions:

``` r
leaves <- find_terminal_nodes(allx$xpath)

new_fields <- allx |>
  filter(xpath %in% leaves, !is.na(count_occurrences), is.na(variable_name)) |>
  select(xpath, count_occurrences, schema_versions)

new_fields
#>                                             xpath count_occurrences schema_versions
#> 1 /Return/ReturnData/IRS990/NewSchemaField2024Amt                 1        2022v5.0
```

There it is: the injected `NewSchemaField2024Amt`, seen in `2022v5.0`,
with no concordance entry. In a real corpus this is your **worklist** —
each row is a new or previously-unmapped field to add to the master
concordance, and its `schema_versions` tells you which form versions it
belongs to.

## Step 4 — Refreshing the packaged concordance

Discovering new fields is upstream work: you add the new
`xpath → variable_name → rdb_table` mappings to the [master concordance
file on
GitHub](https://github.com/Nonprofit-Open-Data-Collective/irs-efile-master-concordance-file).
Once that is published, pull it back into the package:

``` r
# Is the packaged copy behind the GitHub master?
concordance_is_current()

# Refresh data/concordance.rda from GitHub (package-maintenance helper)
update_concordance()
```

[`concordance_is_current()`](https://nonprofit-open-data-collective.github.io/ef2/reference/concordance_is_current.md)
compares the packaged data against the GitHub master and reports whether
it is stale;
[`update_concordance()`](https://nonprofit-open-data-collective.github.io/ef2/reference/update_concordance.md)
downloads and rebuilds the packaged copy. (These are also wired into the
package’s rebuild step, so a stale concordance is caught automatically —
see `dev/update-pkg.R`.)

## What you learned

- `generate_xpath_report(year, base_path)` builds a per-year census of
  XPaths with occurrence counts and schema versions.
- `process_xpaths(years, base_path, concordance)` aggregates those
  reports across years and merges them against the concordance, so
  unmapped XPaths surface as rows with `NA` concordance columns.
- Filtering to
  [`find_terminal_nodes()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_terminal_nodes.md)
  isolates genuine new **data** fields from structural container nodes.
- Once the master concordance is extended,
  [`update_concordance()`](https://nonprofit-open-data-collective.github.io/ef2/reference/update_concordance.md)
  /
  [`concordance_is_current()`](https://nonprofit-open-data-collective.github.io/ef2/reference/concordance_is_current.md)
  bring the packaged copy back in sync.
