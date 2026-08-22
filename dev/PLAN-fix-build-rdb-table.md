# Implementation plan — fix `build_rdb_table()`

Fixes EF2-6 (unanchored header regex) and, as a side effect, the 12 columns lost
to missing header entries and the 19 stray columns from EF2-7. Background and
evidence: `dev/UPSTREAM-ISSUES.md`.

**Scope: one filter, inside one function.** `build_rdb_table()` keeps its
`TYPE=='terminal'` filter, its `TABLE_ID` pivot, its `KEYS` join and its column
ordering. Nothing else in the pipeline changes.

This is **not** a replacement of `build_rdb_table()` by `flatten_table()`. Those
two are dispatched by table type and are not interchangeable — `flatten_table()`
has no `TABLE_ID` pivot, so pointing it at a one-to-many table would collapse
`SR-P04-2012` from 467,522 rows to 14,583. Only the filter is borrowed.

---

## Step 1 — rescue `ExpenseAccount` first  (blocking)

`/Return/ReturnData/IRS990EZ/CompensationOfHighestPaidEmpl/ExpenseAccount` is
absent from the concordance but currently reaches
`F9-P07-T01-COMPENSATION-HCE-EZ` as a stray column carrying **194 real values in
TY2012**. Under the new filter it is dropped silently.

Add it to the concordance with a proper `variable_name` and `rdb_table`, then
confirm it survives the rebuild. It is the only populated casualty — every other
stray column is entirely empty — so this is small and bounded, but it must happen
**before** the switch, not after.

Check other years as well; 194 is the TY2012 count and the variable may carry
values elsewhere.

## Step 2 — the code change

Current:

```r
build_rdb_table <- function( table_name, year, TABLE.HEADERS, con, cc_file, post_to_s3 = FALSE ) {

  hd <- TABLE.HEADERS[[ table_name ]]
  hd <- gsub( "//", "/", hd )
  xpath_versions <- paste0( hd, collapse = "|" )

  db <- dplyr::tbl( con, paste0( "EFILE", year, ".FLATXML" ) )

  wide_xx <- db %>%
    dplyr::filter( grepl( xpath_versions, .data$XPATH2 ) ) %>%
    dplyr::filter( .data$TYPE == "terminal" ) %>%
    ...
```

Proposed. `TABLE.HEADERS` is retained and a `selection` argument added so both
paths can run side by side during validation. The caller
(`extract_csv_tables()`, line ~208) passes positionally and needs no change:

```r
build_rdb_table <- function( table_name, year, TABLE.HEADERS, con, cc_file,
                             post_to_s3 = FALSE,
                             selection = c( "rdb_table", "header" ) ) {

  selection <- match.arg( selection )
  db <- dplyr::tbl( con, paste0( "EFILE", year, ".FLATXML" ) )

  if ( selection == "rdb_table" ) {
    # Exact assignment made during flattening from the concordance. Cannot
    # collide: every xpath maps to exactly one rdb_table. Replaces an
    # unanchored grepl() on TABLE.HEADERS -- see dev/UPSTREAM-ISSUES.md EF2-6.
    sel <- db %>% dplyr::filter( .data$RDB_TABLE == table_name )
  } else {
    # LEGACY. Retained only to reproduce pre-fix output for diffing.
    hd <- gsub( "//", "/", TABLE.HEADERS[[ table_name ]] )
    sel <- db %>% dplyr::filter( grepl( paste0( hd, collapse = "|" ), .data$XPATH2 ) )
  }

  wide_xx <- sel %>%
    dplyr::filter( .data$TYPE == "terminal" ) %>%
    dplyr::select( .data$OBJECTID, .data$TABLE_ID, .data$VARIABLE_NAME, .data$VALUE ) %>%
    tidyr::pivot_wider( names_from  = .data$VARIABLE_NAME,
                        values_from = .data$VALUE,
                        values_fill = "" )
  ...
```

Everything from the `KEYS` join onward is unchanged.

### Add an assertion while you are in there

After `new.order` is computed, every remaining column should be a key,
`TABLE_ID`, or a concordance variable. Under the old filter that was false — it
is how `AddressOfContractor` reached the published files. Under the new one it
should hold, so assert it rather than trusting it:

```r
  stray <- setdiff( colnames( wide_xx ), c( key.names, "TABLE_ID", new.order ) )
  if ( length( stray ) ) {
    warning( sprintf( "%s-%s: %d column(s) not in the concordance: %s",
                      table_name, year, length( stray ),
                      paste( stray, collapse = ", " ) ), call. = FALSE )
  }
```

Warn rather than stop. A surprise here is worth surfacing, not worth aborting a
16-year rebuild over.

### Empty-selection guard

A table legitimately has no rows in some years. Return early rather than letting
`pivot_wider()` produce a zero-column frame.

## Step 3 — pre-flight

`RDB_TABLE` must be populated in every database you intend to rebuild. Already
verified:

| year | terminal cells | unmapped | share |
|---|---|---|---|
| 2009 | 24,381,285 | 49,430 | 0.203% |
| 2010 | 80,700,307 | 101,073 | 0.125% |
| 2011 | 104,259,623 | 113,748 | 0.109% |
| 2012 | 114,393,213 | 134,479 | 0.118% |
| 2013 | 123,460,644 | 137,224 | 0.111% |
| 2024 | 168,210,469 | 186,672 | 0.111% |

Run the same check on 2014–2023 before rebuilding those. If any year shows a
sharply higher share, stop and find out why first.

## Step 4 — validate by diffing, not by inspection

For each of the 62 one-to-many tables, across years spanning the schema change
(2011, 2012, 2013, 2024), build both ways and compare:

```r
old <- build_rdb_table( t, y, TH, con, ccf, selection = "header"    )
new <- build_rdb_table( t, y, TH, con, ccf, selection = "rdb_table" )
```

Expected outcomes and what each means:

| observation | reading |
|---|---|
| identical rows and columns | unaffected — should be the large majority, and all of TY2024 |
| `new` has **fewer columns**, all dropped ones empty | EF2-7 stray columns removed. Correct. |
| `new` has **fewer rows** | EF2-6 collision fixed. Expect on `SR-P01`, `SR-P02`, `SA-P01`, `SH-P05`, `SK-P01` pre-2013. |
| `new` has **more columns** | missing-header entries resolved — expect exactly `F9-P07-T01-COMPENSATION` (+9) and `SH-P05-T99-SUPPLEMENTAL-INFO` (+3) |
| `new` has **more rows** | **not expected. Stop and investigate.** |
| `new` empty where `old` was not | **not expected. Stop and investigate.** |

Anchor case with known numbers: `SR-P01` terminal cells, TY2012, should fall from
**7,477,128 to 156,696**. TY2024 should be **247,715 both ways**.

Do not treat a table appearing in the audit as proof it is corrupt. `SR-P04-2012`
appears in it, diffs identically, and is correct — its inflation is pathological
source filings, not extraction (EF2-1).

## Step 5 — retire the header machinery

`TABLE.HEADERS` has exactly one consumer, `build_rdb_table()`. The
`TABLE_HEADER` column in `FLATXML` is computed per row by `get_header()` from the
xpath itself and does not read the list.

Once `selection = "rdb_table"` is the only path in use:

- `get_table_headers()` and the `TABLE.HEADERS` argument become vestigial. Keep
  them while `selection = "header"` is still needed for diffing, then remove both
  and drop `table_headers` from `extract_csv_tables()`.
- **`audit_table_headers()` becomes obsolete, not retargeted.** It audits a
  mechanism nothing consults. Do not cite it passing as evidence about the new
  pipeline. Delete it, or keep it clearly marked as a check on retired code.
- Replace it with the two checks that do bear on the new path:
  1. `RDB_TABLE` is non-empty for every terminal cell (Step 3's query)
  2. every concordance xpath maps to exactly one `rdb_table`

## Step 6 — rebuild and republish

Priority order:

1. **TY2009–2012**, where the collisions bite hardest.
2. **The 5 mis-captured xpaths reaching TY2013+**, e.g.
   `Form990ScheduleAPartIVGrp/ExplanationTxt`, still matched by
   `Form990ScheduleAPartI`. Small, but current.
3. **Everything else**, for the +12 recovered columns and the −19 stray ones.

Diff each regenerated file against the published one before replacing it, and
keep the diffs. They are the evidence the republish was warranted.

## Downstream notice

`superstructure` consumes these CSVs and pins the 61-column dyad contract against
them. A republish changes column sets on `F9-P07-T01-COMPENSATION` (+9) and
`SH-P05-T99` (+3), and row counts on the pre-2013 Schedule R and Schedule A
tables. Tell that repo before replacing published files; its
`inst/extdata/concordance.csv` and `ensure_table_cols()` padding both key off the
column set.

Note also that fixing EF2-6 does **not** remove the need for downstream
deduplication. Schedule R inflation has two causes and only this one is fixable
here; source filings carrying tens of thousands of duplicated repeating groups
(one TY2012 filing has 32,768 groups for 637 entities, confirmed in the raw IRS
XML) are unfixable at any point in this pipeline.

## Out of scope, tracked separately

EF2-7's second population: **123 xpaths, 130,625 cells, 27,753 of them carrying
values**, reaching no published table at all because they were never added to the
concordance. Nothing here touches them. That is a concordance completeness audit,
and it is the larger of the two problems.
