# Audit TABLE.HEADERS for cross-table misfires

[`build_rdb_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_rdb_table.md)
selects a table's rows with an **unanchored** regular expression:

## Usage

``` r
audit_table_headers(
  TABLE.HEADERS = get_table_headers(),
  cc = NULL,
  verbose = TRUE
)
```

## Arguments

- TABLE.HEADERS:

  Named list of header xpaths per table. Defaults to
  [`get_table_headers()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_table_headers.md).

- cc:

  Concordance data frame with at least `xpath` and `rdb_table`. Defaults
  to the packaged `concordance`.

- verbose:

  Print a summary. Default `TRUE`.

## Value

A data frame, one row per (table, foreign table) misfire, with columns
`table_name`, `steals_from`, `n_xpaths`, `example_xpath`. Zero rows
means no header can capture another table's xpaths. Carries attribute
`"unmatched"`: xpaths the concordance assigns to a table whose header
does NOT match them (the opposite failure – silently missing columns).

## Details

    hd <- gsub( "//", "/", TABLE.HEADERS[[ table_name ]] )
    xpath_versions <- paste0( hd, collapse = "|" )
    dplyr::filter( grepl( xpath_versions, XPATH2 ) )

Because [`grepl()`](https://rdrr.io/r/base/grep.html) matches anywhere
in the string, a header that is a substring of another header captures
rows that belong to a different table. The IRS part naming makes this
easy to hit: `Form990ScheduleRPartI` is a substring of
`Form990ScheduleRPartII`, `...PartIII` and `...PartIV`, so a pre-2013
`SR-P01` extraction silently absorbs Parts II, III and IV.

This is decidable without touching any data: run every header regex
against every xpath in the concordance, and compare the `rdb_table` the
concordance assigns to each matched xpath against the table being built.

The audit reports both directions. Measured against the packaged
concordance: 31 collisions across 17 tables (603 xpaths captured by the
wrong table), and 12 xpaths in 2 tables that their own header does NOT
match, so those columns never appear in the output at all.

Note the header list is structurally complete – 62 one-to-many tables,
62 entries – so no collision here is caused by a MISSING table entry.
They are caused by entries that are present but are prefixes of one
another.

SCOPE. `TABLE.HEADERS` has exactly one consumer,
[`build_rdb_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_rdb_table.md).
The `TABLE_HEADER` column in `FLATXML` is computed per row by
[`get_header()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_header.md)
from the xpath itself and does not read this list. So if
[`build_rdb_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_rdb_table.md)
is ever switched to select on `RDB_TABLE` (see `dev/UPSTREAM-ISSUES.md`,
EF2-6 Step 1), the list stops deciding anything and this function
becomes obsolete rather than merely needing new expectations. Do not
treat it as passing evidence about a pipeline that no longer consults
headers.
