# ef2

**Build and maintain the IRS 990 e-file database: retrieve the XML
filings, flatten them into DuckDB, and extract analysis-ready relational
tables.**

The IRS publishes every electronically filed Form 990, 990-EZ and 990-PF
as an XML document: millions of deeply nested trees whose schema changes
from year to year. `ef2` turns them into the NCCS efile tables. It finds
the filings, parses each one, maps every xpath to a standard variable
name and table through the
[concordance990](https://github.com/Nonprofit-Open-Data-Collective/concordance990)
crosswalk, and pivots the result into about 136 tables a year for the
990 and 83 for the 990-PF, published as CSV and Parquet.

`ef2` is the second generation of
[irs990efile](https://github.com/Nonprofit-Open-Data-Collective/irs990efile).
That package built every table straight from the XML, about three days
per tax year, and kept nothing in between. `ef2` **flattens each filing
once** into a long DuckDB table, one row per XML node, and then builds
every table as a SQL pivot over that archive. A tax year builds in about
15 minutes. A table can be rebuilt, added or corrected without
re-reading any XML, and an archive is kept current by appending new
filings rather than starting over.

## Installation

``` r
# install.packages("pak")
pak::pak("Nonprofit-Open-Data-Collective/ef2")
```

Releases are tagged on GitHub. To install a specific version:

``` r
pak::pak("Nonprofit-Open-Data-Collective/ef2@v2.0.0")
```

See the
[changelog](https://nonprofit-open-data-collective.github.io/ef2/news/index.md)
for what changed in each release.

## The published data

You don’t need to run the pipeline to use the data. The current release,
`efile_v3_1`, covers tax years 2009–2025: 6.3 million 990 and 990-EZ
filings and 1.2 million 990-PF filings.

| What | Where |
|----|----|
| 990 tables (CSV + Parquet) | `https://nccs-efile.s3.us-east-1.amazonaws.com/public/efile_v3_1/` |
| 990-PF tables (CSV + Parquet) | `https://nccs-efile.s3.us-east-1.amazonaws.com/public/efilepf_v3_1/` |
| 990 DuckDB archives | `https://nccs-efile.s3.us-east-1.amazonaws.com/duckdb/efile_v3_1/EFILE<YEAR>.duckdb` |
| 990-PF DuckDB archives | `https://nccs-efile.s3.us-east-1.amazonaws.com/duckpf/efilepf_v3_1/EFILEPF<YEAR>.duckdb` |

Tables are named `<TABLE>-<YEAR>.CSV` / `.parquet`, for example
`F9-P08-T00-REVENUE-2022.parquet`. Each table folder has a row-count
sheet and release notes. The tables are also listed on the [NCCS
website](https://nccs.urban.org/nccs/datasets/efile/).

The archives are large (up to about 26 GB), so query them in place
rather than downloading them. DuckDB reads only the pages a query needs:

``` r
con <- get_s3_database( filename = "EFILE2021.duckdb", version = "efile_v3_1" )
```

Read the published CSVs with every column as character.
[`data.table::fread()`](https://rdrr.io/pkg/data.table/man/fread.html)
and [`read.csv()`](https://rdrr.io/r/utils/read.table.html) cast
`ORG_EIN` to an integer and drop its leading zeros. The Parquet files
have no such problem.

## The process

Building the database has two stages. The first parses XML into a flat
archive. The second turns that archive into tables. The second stage
never touches XML, which is where the speed and stability come from.

      GTDC + IRS indices ──► 1. find filings ──► 2. build / 3. update ──► DuckDB archive
                                                                          (KEYS, FLATXML,
                                                                           ATTRIBUTES)
                                                                                │
              release notes ◄── 5. compare releases ◄── 4. extract tables ◄─────┘

### 1. Find the filings to process

The Giving Tuesday Data Commons (GTDC) indexes the IRS XML files. Its
index skips some IRS batches, so `ef2` also builds a patch index of the
missing filings from the IRS bulk downloads and re-hosts their XML.

``` r
gt    <- get_current_index_full()            # newest GTDC index
patch <- data.table::fread(                  # filings GTDC never indexed
  "https://nccs-efile.s3.us-east-1.amazonaws.com/xml2/v2_3_patch/PATCH-INDEX-v2_3-2026-10-07.csv",
  colClasses = "character" )
index <- combine_index( gt, patch )          # one row per filing; GTDC preferred
index <- dplyr::filter( index, FormType %in% c( "990", "990EZ" ) )
```

To find what an existing archive is missing, compare the index with it
by `OBJECTID`:

``` r
missing <- find_missing_urls( year = 2024, index = index, version = "efile_v3_1" )
```

Vignette: [Identifying new returns to
process](https://nonprofit-open-data-collective.github.io/ef2/articles/identify-new-returns.md).

### 2. Build a new database

[`build_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_database.md)
splits the URLs into batches. Parallel workers claim batches from a
shared queue, flatten each filing, and write to their own DuckDB shard.
The shards are then merged into `EFILE<year>.duckdb`. A failed or slow
filing affects only its batch, and an interrupted build resumes from the
batches that are left.

``` r
index_y <- dplyr::filter( index, TaxYear == "2024" )
build_database( year = 2024, urls = index_y$URL,
                ccf = release_concordance( "efile_v3_1" ) )
```

Duplicate filings are dropped before batching
([`dedupe_urls()`](https://nonprofit-open-data-collective.github.io/ef2/reference/dedupe_urls.md)),
and
[`check_unique_keys()`](https://nonprofit-open-data-collective.github.io/ef2/reference/check_unique_keys.md)
confirms after the merge that each filing appears once.

Install `ef2` before building, with
[`devtools::install()`](https://devtools.r-lib.org/reference/install.html).
The workers are separate R sessions that load the installed package and
never see code loaded with
[`devtools::load_all()`](https://devtools.r-lib.org/reference/load_all.html).

### 3. Update an existing database

[`update_db()`](https://nonprofit-open-data-collective.github.io/ef2/reference/update_db.md)
finds the filings an archive lacks, builds only those, and appends them.
It labels them with the concordance the archive was released with, read
from the archive’s `RELABEL_LOG`, so one archive never mixes two label
sets.

``` r
update_db( year = 2024, index = index_y,
           source_db = "EFILE2024.duckdb" )  # local archive, updated in place
```

Vignette: [Updating a DuckDB database with missing
files](https://nonprofit-open-data-collective.github.io/ef2/articles/updating-duckdb.md).

### 4. Extract the tables

Each table is selected from `FLATXML` by its concordance table name and
pivoted wide: one row per filing for one-to-one tables, one row per
repeated group (a grant, an officer, a related organization) for
one-to-many tables.

``` r
extract_csv_tables(
  wd          = "C:/efile",
  years       = 2020:2022,
  table_names = c( "F9-P08-T00-REVENUE", "F9-P09-T00-EXPENSES", "F9-P10-T00-BALANCE-SHEET" ),
  output      = "both"                       # CSV and Parquet
)
```

Both formats are written from the same query result, and
[`verify_table_output()`](https://nonprofit-open-data-collective.github.io/ef2/reference/verify_table_output.md)
checks that each pair agrees row for row.

Vignettes: [Extracting one-to-one
tables](https://nonprofit-open-data-collective.github.io/ef2/articles/extract-one-to-one-tables.md)
and [Extracting one-to-many
tables](https://nonprofit-open-data-collective.github.io/ef2/articles/extract-one-to-many-tables.md).

### 5. Compare releases

[`compare_releases()`](https://nonprofit-open-data-collective.github.io/ef2/reference/compare_releases.md)
diffs two releases of the tables, local or on S3: tables added and
dropped, row and column changes, filings by tax year, and xpaths moved
between concordances.
[`write_release_notes()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_release_notes.md)
renders the result as Markdown.

``` r
cmp <- compare_releases( "public/efile_v2_3/", "public/efile_v3_1/" )
write_release_notes( cmp, "RELEASE-NOTES.md", title = "efile_v3_1" )
```

When the IRS changes its schema, new xpaths need concordance entries.
See [Updating the concordance for IRS schema
changes](https://nonprofit-open-data-collective.github.io/ef2/articles/updating-the-concordance.md).

## The flattened XML

Everything after step 2 works from one table, `FLATXML`, so its
structure is worth knowing. Here is one grant from a Schedule I, as
filed:

``` xml
<RecipientTable>
  <RecipientBusinessName>
    <BusinessNameLine1Txt>100WOMEN STRONG</BusinessNameLine1Txt>
  </RecipientBusinessName>
  <USAddress>
    <AddressLine1Txt>714 EAST MARKET STREET</AddressLine1Txt>
    <CityNm>LEESBURG</CityNm>
    <StateAbbreviationCd>VA</StateAbbreviationCd>
    <ZIPCd>20178</ZIPCd>
  </USAddress>
  <RecipientEIN>541950727</RecipientEIN>
  <IRCSectionDesc>INTERFUND GRANT</IRCSectionDesc>
  <CashGrantAmt>40250</CashGrantAmt>
  <NonCashAssistanceAmt>0</NonCashAssistanceAmt>
  <PurposeOfGrantTxt>HUMAN SERVICES</PurposeOfGrantTxt>
</RecipientTable>
```

Flattened, every node becomes a row. Here xpaths are shortened to start
at `/IRS990ScheduleI`:

| XPATH | TYPE | TABLE_ID | VARIABLE_NAME | VALUE |
|----|----|----|----|----|
| …/RecipientTable\[1\] | parent | TID-000-000-001 |  |  |
| …/RecipientTable\[1\]/RecipientBusinessName | parent | TID-000-000-001 |  |  |
| …/RecipientBusinessName/BusinessNameLine1Txt | terminal | TID-000-000-001 | SI_02_GRANT_US_ORG_NAME_L1 | 100WOMEN STRONG |
| …/RecipientTable\[1\]/USAddress | parent | TID-000-000-001 |  |  |
| …/USAddress/AddressLine1Txt | terminal | TID-000-000-001 | SI_02_GRANT_US_ORG_ADDR_L1 | 714 EAST MARKET STREET |
| …/USAddress/CityNm | terminal | TID-000-000-001 | SI_02_GRANT_US_ORG_ADDR_CITY | LEESBURG |
| …/USAddress/StateAbbreviationCd | terminal | TID-000-000-001 | SI_02_GRANT_US_ORG_ADDR_STATE | VA |
| …/USAddress/ZIPCd | terminal | TID-000-000-001 | SI_02_GRANT_US_ORG_ADDR_ZIP | 20178 |
| …/RecipientTable\[1\]/RecipientEIN | terminal | TID-000-000-001 | SI_02_GRANT_US_ORG_EIN | 541950727 |
| …/RecipientTable\[1\]/IRCSectionDesc | terminal | TID-000-000-001 | SI_02_GRANT_US_ORG_IRC_SECTION | INTERFUND GRANT |
| …/RecipientTable\[1\]/CashGrantAmt | terminal | TID-000-000-001 | SI_02_GRANT_US_ORG_AMT_CASH | 40250 |
| …/RecipientTable\[1\]/NonCashAssistanceAmt | terminal | TID-000-000-001 | SI_02_GRANT_US_ORG_AMT_NONCSH | 0 |
| …/RecipientTable\[1\]/PurposeOfGrantTxt | terminal | TID-000-000-001 | SI_02_GRANT_US_ORG_PURPOSE | HUMAN SERVICES |

Every terminal row here also carries
`RDB_TABLE = SI-P02-T01-GRANTS-US-ORGS-GOVTS`. The columns that matter
most:

| Column | Meaning |
|----|----|
| `OBJECTID` | The filing’s ID, `OID-` plus the IRS object ID |
| `XPATH` | The node’s full path, with repeat indices such as `[1]` |
| `XPATH2` | The same path with indices and namespaces stripped; it joins the concordance |
| `TYPE` | `parent` nodes only group other nodes; `terminal` nodes hold the data |
| `TABLE_ID` | Which repeat of a group the node belongs to. `TID-000-000-000` is one-to-one data; `TID-000-000-001`, `-002`, … are the first, second, … grant |
| `RDB_TABLE` | The table the node belongs to, from the concordance |
| `VARIABLE_NAME` | The standard variable name, from the concordance |
| `VALUE` | The node’s text |

Extracting a table keeps the terminal rows for its `RDB_TABLE` and
pivots `VARIABLE_NAME` into columns, one row per `OBJECTID` and
`TABLE_ID`. This grant becomes one row of
`SI-P02-T01-GRANTS-US-ORGS-GOVTS`:

| OBJECTID | TABLE_ID | SI_02_GRANT_US_ORG_NAME_L1 | SI_02_GRANT_US_ORG_ADDR_CITY | SI_02_GRANT_US_ORG_AMT_CASH | … |
|----|----|----|----|----|----|
| OID-202341529349301414 | TID-000-000-001 | 100WOMEN STRONG | LEESBURG | 40250 | … |

Each archive also has a `KEYS` table, which every table joins. It holds
one row per filing with its EIN, name, tax year and form type, plus
flags for amended and partial-year returns. It also has an `ATTRIBUTES`
table holding the XML attributes, such as the 501(c) subsection number.

The [Flattening IRS 990 e-file
XML](https://nonprofit-open-data-collective.github.io/ef2/articles/flatten-xmls.md)
vignette works through a full filing: parent and terminal nodes, table
headers, and how `TABLE_ID` separates one-to-one from one-to-many data.

## Working with the tables

The `ef2` tables work with **panel990**, **fiscal**, **governance** and
the other packages in the Nonprofit Open Data Collective ecosystem:

``` r
library(panel990)                         # pak::pak("nonprofit-open-data-collective/panel990")
panel <- panelize( tables = c( "P00", "P01", "P08", "P09", "P10" ),
                   years = 2019:2022, bmf = TRUE )

library(fiscal)                           # pak::pak("nonprofit-open-data-collective/fiscal")
ratios <- compute_all( as.data.frame( panel ) )   # ~50 fiscal-health metrics
```
