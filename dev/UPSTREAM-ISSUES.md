# EF2 / NCCS Table Issues — Upstream Register

Defects in the **tables this package produces**, and in the NCCS extract that
feeds them.

Findings here were gathered downstream, in the `superstructure` package, which
consumes these tables. They are recorded here because this is where they get
fixed. Section references of the form `superstructure/dev/...` point into that
repository.

Nothing here is fixed by editing a downstream detector, and the standing
decision is **not to build machinery downstream that papers over these**,
because a convincing workaround removes the pressure to fix the real thing and
silently changes what users of these tables think they are looking at.

## Where a finding belongs

| Finding | Goes in |
|---|---|
| The source table is wrong, malformed, or mis-parsed | **this file** |
| Filers answer a form field inconsistently | `superstructure/dev/DESIGN-DECISIONS.md` |
| A consumer read a correct table incorrectly | `superstructure/dev/BUILD-LOG.md` |
| Root-cause investigation, evidence, xpaths | `superstructure/dev/DEVNOTES.md` |

The distinction that matters most is the second row. A filer typing a person's
name into `BusinessName` is **not an ef2 bug** — ef2 faithfully reproduced what
was filed. Filing that here would send someone to fix code that is already
correct. See "Explicitly not ef2 issues" below.

---

## EF2-1 — Pre-2013 Schedule R is a cartesian product

**Status: fix upstream. Do not extend the local workaround.**

TY2009–2012 Schedule R rows are cross-joined across parts, inflating counts by
up to **11.9x** on `SR-P01`. Full evidence, the measured inflation table, and
the xpath-level root cause are in `superstructure/dev/DEVNOTES.md` §22–23; they are not repeated
here.

### Where the defect is NOT (measured 2026-08-21, against `EFILE2009.duckdb`)

An earlier root-cause note downstream blamed the xpath extraction. **That is
wrong, and the correction matters because it points at different code.**

The `FLATXML.XPATH2` values for TY2009 are **correctly part-anchored**:

```
Form990ScheduleRPartI /NameOfDisregardedEntity/BusinessNameLine1    4,642
Form990ScheduleRPartII/NameOfDisregardedEntity/BusinessNameLine1   91,984
```

The two parts genuinely do reuse the element name `NameOfDisregardedEntity` --
that observation was right -- but the flattener keeps them apart. The current
concordance also keeps them apart, mapping the two anchored xpaths to
`SR_01_DISREG_ENTITY_NAME_L1` / `SR-P01-...` and `SR_02_RLTD_ORG_NAME_L1` /
`SR-P02-...` respectively.

So neither `R/03_flatten_xml.R` nor the schema map produces the collision.

### Where it therefore must be

The published pre-2013 `SR-P01` CSV carries `SR_02_*`, `SR_03_*` and `SR_04_*`
columns, so at the time those CSVs were built, variables from several parts were
being written into one table and then pivoted together.

**Check first:** whether this is still reproducible, or whether it only afflicts
the *already-published* pre-2013 CSVs. If regenerating TY2009 from the current
DuckDB and current concordance yields a clean `SR-P01`, the pipeline is already
fixed and the task is a re-publish, not a code change. That is a cheap test and
it should precede any other work here.

**CONFIRMED — see EF2-6.** The mechanism is the unanchored `grepl()` in
`build_rdb_table()`'s row-selection step. `SR-P01`'s header
`//IRS990ScheduleR/Form990ScheduleRPartI` is a *substring* of `PartII`,
`PartIII` and `PartIV`, so building `SR-P01` admits all four parts. `SR-P02`
likewise admits `PartIII`. `SR-P03` and `SR-P04` are clean.

That also explains why the defect stops at 2013: the post-2013 headers are
`IdDisregardedEntitiesGrp` and `IdRelatedTaxExemptOrgGrp`, which share no
prefix.

Two other hypotheses were tested and **ruled out**, so nobody need revisit them:

- *`KEYS` has duplicate `OBJECTID`s, inflating the `right_join()`.* No. TY2009
  and TY2012 both have exactly one `KEYS` row per `OBJECTID`. (The dedupe in
  `generate_xpath_report()` is defensive, not evidence of a real duplicate.)
- *`get_table_id()` collapses repeating-group rows.* No. Measured on TY2012,
  `Form990ScheduleRPartIV[1..4]` correctly yields `TID-00001..00004`.

**`SR-P04`'s 2.64x is RESOLVED, and it is not an ef2 defect.** Regenerating
`SR-P04-2012` and diffing against the published CSV: both the header regex and
`RDB_TABLE` select **exactly the same 467,522 rows**, the header admits nothing
foreign, and the published file matches row for row with no foreign-part
columns. The extraction is faithful.

The 2.643 ratio comes from a handful of **pathological source filings**. Rows
per filing: median 2, mean 32.05, max **32,768**. For
`OID-201312829349300956`, `FLATXML` itself holds 32,768 distinct `TABLE_ID`s
from 131,072 cells, with xpaths running `Form990ScheduleRPartIV[1]` through
`[32768]` -- correctly anchored and correctly indexed -- carrying only **637
distinct counterparty names**. The filing genuinely contains 32,768 repeating
groups for 637 entities.

**Consequence for the Schedule R inflation generally: it has TWO causes, and
only one is fixable here.**

1. Header prefix collision (EF2-6) -- a real defect in this package, affecting
   `SR-P01` and `SR-P02`. Fixable.
2. Source filings with massively duplicated repeating groups -- present in the
   XML before this package sees it, affecting any part. **Not fixable here, ever.**

That vindicates downstream deduplication as permanent handling rather than a
temporary workaround: `superstructure`'s `dedupe_dyads()` is the correct
response to cause 2 and should not be retired when EF2-6 is fixed.

**Why this cannot be fully repaired downstream.** `dedupe_dyads()` recovers the
distinct *counterparties*, but the cross-join reassigned `TABLE_ID`, so the
function has to set `row_seq` to NA on affected filings. That is the
provenance link back to the original repeating-group row, and it is **gone** —
no amount of local cleverness reconstructs it. Only re-parsing with anchored
xpaths restores it. That, on its own, is the argument for fixing it in ef2.

**Do not build:** part-inference heuristics, per-part row reconstruction, or
anything that attempts to work out which Part I row a cross-joined record
"really" came from. That is the glue that masks the problem.

**Blast radius if unfixed:** TY2009–2012 only. The 2022–2024 build does not
touch this path. Any full-panel build does.

**Where to look:** `R/08_extract_csv_tables.R` (the `pivot_wider()` on
`OBJECTID` + `TABLE_ID`) and `get_table_id()` in `R/99_utils.R`. Not the
flattener, and not the concordance -- both were checked and are correct.

---

## EF2-2 — Blank key columns on a small number of 2024v5.1 rows

Four `F9-P07-T01-COMPENSATION` rows in the 2022–2024 build carry a populated
`PersonNm` but **NULL `ORG_EIN` and NULL `TAX_YEAR`**, across two OBJECTIDs.
They surface as `person_bridges` rows with no filing year and no filer.

`ORG_EIN` and `TAX_YEAR` are key columns — they should never be blank on a row
that exists. `dyad_edges` has zero nulls in either field across all 6.8M rows,
so this is confined to the person side and looks like an extraction gap rather
than anything structural.

Four rows out of 14.8M. Recorded for the pattern, not the magnitude; left
unhandled deliberately, since a local guard here would hide a key-column defect
that should be impossible.

---

## EF2-3 — 136 concordance variables carry multiple location codes

136 of 2,318 variables map to more than one location code — most often the same
field appearing on both the 990 and the 990-EZ. `provenance_map()` joins them
with `" | "` rather than picking one.

An earlier version took `.SD[1]`, which silently reported a 990-EZ location
code for a 990-only detector. That was a package bug and is fixed
(`superstructure/dev/BUILD-LOG.md`), but the underlying ambiguity is a **concordance** property: a
consumer asking "where did this field come from" gets a list, not an answer.

Not necessarily wrong — a field genuinely can appear in two places — but it
should be a deliberate modelling decision upstream rather than something each
consumer resolves differently.

---

## EF2-4 — Schema coverage stops at TY2023

Every schema source available locally ends at 2023: the `990-schemas` repo holds
37,281 XSDs for 2003–2023, and concordance versions end there too. The IRS gates
TY2024 schemas behind e-Services SOR.

Consequence: for TY2024+ questions, raw filing XML via the `URL` column is the
only authority. `schema_version` on each row (e.g. `2024v5.2`) at least records
which version a filing used, so the gap is visible per-row instead of inferred.

Not a defect, but it bounds what can be validated and is worth stating once.

---

## EF2-5 — `generate_xpath_report()` cannot read the published S3 databases

Not a data defect; a gap in this package's own tooling, recorded here because it
is the thing standing between EF2-1 and a five-minute confirmation.

`generate_xpath_report()` resolves its database as

```r
db_path <- file.path(base_path, year, paste0("EFILE", year, ".duckdb"))
if (!file.exists(db_path)) stop("Database not found at: ", db_path)
```

Two problems for the published archives at
`https://nccs-efile.s3.dualstack.us-east-1.amazonaws.com/duckdb/efile_v2_2/`
(TY2009-2024):

1. **Layout.** The function expects `base_path/<year>/EFILE<year>.duckdb`. S3 is
   flat: `.../efile_v2_2/EFILE<year>.duckdb`, no year directory.
2. **`file.exists()` rejects a URL**, so a remote path cannot be passed at all.

Downloading instead is unattractive: **2.8 GB** for 2009, **13.2 GB** for 2012,
**18.3 GB** for 2024 — roughly 100 GB+ for the full panel, to produce a report
that touches one column.

### Remote attach works (verified 2026-08-21)

DuckDB reads these over HTTPS with range requests, pulling only the pages it
needs:

```sql
LOAD httpfs;
ATTACH 'https://nccs-efile.s3.dualstack.us-east-1.amazonaws.com/duckdb/efile_v2_2/EFILE2009.duckdb'
  AS ef (READ_ONLY);
```

Confirmed against TY2009: `ATTACH` succeeded, `ATTRIBUTES` / `FLATXML` / `KEYS`
all visible, and a grouped scan of every Schedule R xpath returned **156 rows in
14.3 seconds** — no download. That query is what produced the EF2-1 correction
above.

**Windows caveat.** The R `duckdb` package on Windows uses the
`windows_amd64_mingw` build, and in-process `INSTALL httpfs` fails there:

```
IO Error: Failed to download extension "httpfs" at URL
"http://extensions.duckdb.org/v1.2.0/windows_amd64_mingw/httpfs.duckdb_extension.gz"
```

The URL itself serves fine over `curl` (HTTP 200), so this is DuckDB's own
downloader, not the network. Workaround that was verified to work: fetch and
gunzip the extension manually, then connect with
`config = list(allow_unsigned_extensions = "true")` and
`LOAD '<path>/httpfs.duckdb_extension'`.

### Suggested change

Give `generate_xpath_report()` a `db_path` argument that accepts a URL, skip the
`file.exists()` gate when the path is remote, and `ATTACH ... (READ_ONLY)`
rather than opening the file directly. `process_xpaths()` then works over the
published archive for all years without a local copy, and `xpath_reports/` --
currently empty -- can be populated for 2009-2024.

---

## EF2-6 — `build_rdb_table()` selects rows with an unanchored regex

> **FIXED 2026-08-22.** `build_rdb_table()` now selects on `RDB_TABLE` and takes
> a `selection` argument (`"rdb_table"` default, `"header"` for diffing).
> Validated against local TY2012/TY2013 archives; results below. The published
> CSVs are **not** yet regenerated — that is Step 6 and is still open.
>
> | table | year | header | rdb_table |
> |---|---|---|---|
> | `SR-P01` | 2012 | 765,251 rows / 96 cols | **15,871 / 34** (−97.9%) |
> | `SR-P01` | 2013 | 18,784 / 34 | 18,784 / 34 (identical) |
> | `SR-P04` | 2012 | 467,522 / 37 | 467,522 / 37 (identical) |
> | `SA-P01` | 2012 | 28,490 / 26 | 26,310 / 25 |
> | `SA-P01` | 2013 | 71,444, **inflation 1.439** | 27,438, **inflation 1.001** |
> | `F9-P07-T01` | 2012 | 2,935,442 / 33 | 2,935,943 / **37** |
>
> Every outcome falls in the protocol's expected column. `SR-P04` identical
> confirms it was never affected. `F9-P07-T01` **gains** four columns —
> `F9_07_COMP_DTK_EXPL_*`, the `CompensationExplanation` root its header list
> never covered — and 501 rows with them, which is the missing-header fix
> adding data rather than a surprise.
>
> **It also closes the SA-P01 TY2013 blip**, recorded downstream as unexplained:
> the legacy path reproduces the 1.44 inflation exactly and the fix returns
> 1.001. 2013 is the Schedule A naming transition, so legacy and `*Grp` filings
> coexist and SA-P01's header list carries both spellings.

**This is the mechanism behind EF2-1, and it is not confined to Schedule R.**

`build_rdb_table()` picks a table's rows like this:

```r
hd <- gsub( "//", "/", TABLE.HEADERS[[ table_name ]] )
xpath_versions <- paste0( hd, collapse = "|" )
dplyr::filter( grepl( xpath_versions, .data$XPATH2 ) )
```

`grepl()` matches **anywhere in the string**. IRS part naming is built from
Roman numerals, so headers are routinely substrings of one another:

```
Form990ScheduleRPartI   is a substring of  PartII, PartIII, PartIV
Form990ScheduleAPartI   is a substring of  PartII, PartIII, PartIVGrp
Form990ScheduleHPartV   is a substring of  PartVSectionA, PartVSectionB, PartVI
Form990ScheduleKPartI   is a substring of  PartII
```

Any table whose header is a prefix of another silently absorbs that table's
rows.

### Measured blast radius

`audit_table_headers()` (added in `R/10_audit_table_headers.R`) runs every
header regex against every concordance xpath and compares the `rdb_table` the
concordance assigns. Against the packaged concordance:

- **31 misfire pairs across 17 tables**
- **603 xpaths captured by the wrong table** (542 distinct)

Largest offenders — and note Schedule R is *not* the worst:

| xpaths | table being built | absorbs |
|---|---|---|
| 100 | `SA-P01-T01-PUBLIC-CHARITY-STATUS` | `SA-P03-T00-SUPPORT_SCHEDULE_509` |
| 60 | `SA-P01-T01-PUBLIC-CHARITY-STATUS` | `SA-P02-T00-SUPPORT_SCHEDULE_170` |
| 46 | `SH-P05-T01-HOSPITAL-FACILITY` | `SH-P99-T00-FAP-COMMUNITY-BENEFIT-POLICY` |
| 42 | `SH-P05-T01-HOSPITAL-FACILITY` | `SH-P05-T00-FAP-COMMUNITY-BENEFIT-POLICY` |
| 32 | `SR-P01-T01-ID-DISREGARDED-ENTITIES` | `SR-P03-...-TAXABLE-PARTNERSHIP` |
| 30 | `SR-P01-T01-ID-DISREGARDED-ENTITIES` | `SR-P04-...-TAXABLE-CORPORATION` |
| 28 | `SR-P01-T01-ID-DISREGARDED-ENTITIES` | `SR-P02-...-RLTD-TAX-EXEMPED-ORGS` |
| 19 | `SK-P01-T01-BOND-ISSUES` | `SK-P02-T01-BOND-PROCEEDS` |

Mostly legacy, but **not exclusively**: of the mis-captured xpaths carrying a
parseable version, 280 end at TY2012 or earlier and **5 still appear in TY2013
or later** — e.g. `Form990ScheduleAPartIVGrp/ExplanationTxt`, which
`Form990ScheduleAPartI` still matches, and `HospitalFacilitiesGrp/FacilityNum`.
So this is not purely historical.

### The opposite failure

The same audit finds headers that do **not** match xpaths the concordance
assigns to their own table — columns that silently never appear. Currently 2
tables, 12 xpaths, led by `F9-P07-T01-COMPENSATION` with 9.

### Fix

Anchor the match. The header identifies a node in a path, so the comparison
should be on a path *segment boundary* rather than a bare substring — e.g.
require the match be followed by `/` or end-of-string, or compare against
`TABLE_HEADER` (already computed by `get_header()`) with `%in%` instead of
regex. Escaping the header for regex use would be prudent regardless.

Whatever the fix, `audit_table_headers()` should return zero rows afterwards —
it is a regression test that needs no data.

```r
audit_table_headers()          # zero rows == no table can capture another's xpaths
```

---

## Plan — fixing the header collisions

> **Implementation plan: `dev/PLAN-fix-build-rdb-table.md`.** That file carries
> the code change, the pre-flight, the diff protocol with expected outcomes, and
> the republish order. What follows is the reasoning behind it — why the obvious
> repair fails, and what each option does and does not fix.

Ordered by evidence. Steps 1 and 2 are independent of each other.

### Step 0 — do not use two-level headers

The obvious repair, giving `SR-P01` the header
`//IRS990ScheduleR/Form990ScheduleRPartI/NameOfDisregardedEntity`, **fixes the
leak and breaks the table.** Tested:

| header | matches PartI name | matches PartII name | matches PartI `EIN` | matches PartI `LegalDomicile` |
|---|---|---|---|---|
| current | yes | **yes (bug)** | yes | yes |
| two-level | yes | no | **no** | **no** |
| anchored | yes | no | yes | yes |

A header names the *repeating group*; pushing it down to one child element
selects only that child's rows, so the table loses every other column. Rejected.

### Step 1 — swap the FILTER inside `build_rdb_table()`  (recommended)

**This is a one-line filter change, not a function replacement.** The two
builders are not interchangeable. `extract_csv_tables()` dispatches by table
type:

```r
purrr::walk( t00, build_table,     year, con, ccf )                   # 66 one-row tables
purrr::walk( t01, build_rdb_table, year, table_headers, con, ccf )    # 62 one-to-many tables
```

`build_table()` / `flatten_table()` handle **one row per filing** and have no
`TABLE_ID` pivot, so they cannot build a 1:M table -- pointing them at `SR-P04`
would collapse 467,522 repeating-group rows into 14,583. What they do have is
the correct selection:

```r
dplyr::filter( .data$RDB_TABLE == table_name )     # exact, cannot collide
```

So: keep `build_rdb_table()`, keep its `TYPE=='terminal'` filter and its
`TABLE_ID` pivot, and replace only its `grepl()` line with that one. Measured on
`SR-P01`, terminal cells:

| | `RDB_TABLE ==` | header regex |
|---|---|---|
| TY2024 | 247,715 | 247,715 (identical) |
| TY2012 | 156,696 | **7,477,128** (47.7x) |

This fixes **all three** collision classes at once, because the concordance
assigns every xpath exactly one `rdb_table` -- including the `T00`/`T01` pairs
that share a node, which anchoring cannot separate.

**The 0.12% of cells with no `RDB_TABLE` have been checked -- see EF2-7. The
switch is safe, with one variable to rescue first (`ExpenseAccount`, 194 values
in TY2012).**

### Step 2 — if `RDB_TABLE` proves unusable, anchor the regex instead

Append a path separator so the match must land on a segment boundary:

```r
hd <- paste0( gsub( "//", "/", TABLE.HEADERS[[ table_name ]] ), "/" )
```

Safe because a header names a repeating group and a terminal row always sits
below it. Measured effect: **31 misfire pairs -> 9; 603 mis-captured xpaths ->
75; 17 affected tables -> 9.** A partial fix, not a complete one.

### Step 3 — one outright duplicate header entry

`SK-P05-T01-PROCEDURE-CORRECTIVE-ACT` and `SK-P06-T99-SUPPLEMENTAL-INFO` **both**
list `//IRS990ScheduleK/Form990ScheduleKPartV`. They absorb each other's rows.
Neither anchoring nor `RDB_TABLE` makes this entry correct -- remove it from
`SK-P06`, whose own nodes are `Form990ScheduleKPartVI` and
`SupplementalInformationDetail`.

### Step 4 — the `T00`/`T01` co-located tables

Seven of the nine residual pairs are a `T01` repeating table and a `T00`
one-row-per-filing table sharing one XML node (`SG-P02`, `SA-P01`, `SD-P10`,
`F9-P07`, `SH-P05`). The `T00` tables have **no header entry at all**, so they
are not built through this path; the `T01` header legitimately matches the node
and picks up the `T00` variables too. Filing-level totals then land on whichever
`TABLE_ID` they carry. Step 1 resolves this; Step 2 does not.

### Step 5 — regression test, and what happens to it

```r
audit_table_headers()      # zero rows
```

Use this **if Step 2 is taken** (anchoring), where the header regex still
decides selection and the audit is a genuine regression test.

**If Step 1 is taken, this function becomes obsolete, not merely retargeted.**
`TABLE.HEADERS` has exactly one consumer in the package -- `build_rdb_table()`.
(The `TABLE_HEADER` column in `FLATXML` is computed per row by `get_header()`
directly from the xpath, and does not read the hand-maintained list.) Swap that
filter and the list stops deciding anything at all; an audit of it passing would
prove nothing about the pipeline. Retire it, or keep it only as documentation of
a retired mechanism, and replace the regression test with:

- is `RDB_TABLE` non-empty for every terminal cell?
- does every concordance xpath map to exactly one `rdb_table`?

### On missing headers -- checked, and mostly not the problem

The list is **structurally complete**: 62 one-to-many tables in the concordance,
62 entries in `TABLE.HEADERS`, a clean 1:1. No 1:M table lacks an entry, no
entry names a table the concordance does not know, and no `T00` table carries a
superfluous entry. **None of the 31 collisions is caused by a missing header** --
every one is caused by a header that is present but short enough to be a prefix
of another.

Missing header *elements within* an entry are a real but separate defect, and
they cause the opposite failure -- columns that silently never appear:

| table | unmatched xpaths | what the header list is missing |
|---|---|---|
| `F9-P07-T01-COMPENSATION` | 9 | the whole `/Return/ReturnData/CompensationExplanation/...` root; its headers only cover `IRS990/Form990PartVIISection*` |
| `SH-P05-T99-SUPPLEMENTAL-INFO` | 3 | `IRS990ScheduleH/SupplementalInformationDetail` |

Those 12 variables are absent from the published tables today. **Step 1 fixes
them too**, and for free: `RDB_TABLE` is assigned from the concordance during
flattening, so it does not care whether anyone remembered to add an xpath to a
hand-maintained list. Step 2 does not fix them -- anchoring a header that was
never there changes nothing.

### Step 6 — republish

Affected years are **TY2009-2012**, plus the 5 mis-captured xpaths that reach
TY2013+. Regenerate and diff against the published CSVs before replacing them --
`SR-P04-2012` was diffed this way and turned out to be faithful, so do not
assume a table is corrupt merely because it appears in the audit.

---

## EF2-7 — xpaths absent from the concordance leak in as stray columns

Found while checking what the `RDB_TABLE ==` switch (EF2-6 Step 1) would drop.

`RDB_TABLE` is empty on 0.12% of terminal cells — 134,479 of 114M in TY2012,
186,672 of 168M in TY2024. **These are cells whose xpath is not in the
concordance at all.** All 125 distinct `VARIABLE_NAME`s on them are absent from
the concordance, because the flattener falls back to the raw XML element name:
`AddressOfContractor`, `FinancialDerivatives`, `Land`, `Buildings`,
`IRS990ScheduleG`. So this is a **concordance coverage gap**, not a
table-assignment gap.

By xpath depth, TY2012:

| depth | cells | paths | what they are |
|---|---|---|---|
| 3 | 10,447 | 17 | the schedule **root node itself**, flagged terminal — `/Return/ReturnData/IRS990ScheduleG`, `/Return/ReturnData/CompensationExplanation` |
| 4 | 101,103 | 94 | real leaves under an unmapped parent |
| 5-6 | 22,929 | 31 | deeper leaves |

79% carry no value at all: they are empty or container elements.

### Two populations, and only one is visible today

**Swept into a published table** by the header regex — 19 paths, 3,854 cells,
of which **194 carry a value**. These become stray columns named after raw XML
elements. Confirmed in the published file: `F9-P07-T02-CONTRACTORS-2012.CSV`
has 30 columns and the 30th is **`AddressOfContractor`** (1,441 cells, none
populated), sitting after the concordance-ordered columns because `relocate()`
does not know about it.

All 194 populated cells are a single variable: **`ExpenseAccount`**, swept into
`F9-P07-T01-COMPENSATION-HCE-EZ`. Every other stray column is entirely empty.

**Not swept anywhere** — 123 paths, 130,625 cells, **27,753 carrying a value**.
These appear in no published table today and are unaffected by either fix. This
is the larger and quieter problem: real filed data that no table exposes because
the xpath was never added to the concordance.

### Consequence for EF2-6 Step 1

Switching selection to `RDB_TABLE ==` **drops all 19 stray columns**, 18 of them
entirely empty. That is a fix, not a regression — those columns should never
have been in the files.

**One thing to rescue first:** `ExpenseAccount` carries 194 real values in
TY2012. Add its xpath to the concordance so it gets a proper variable name and
`rdb_table` before the switch, or those values are silently lost. Dropping an
unmapped variable is the wrong repair when the variable holds data; mapping it
is the right one.

---

## EF2-8 — two dyadic rosters with EINs reach no published table

`AffiliateListing` and `AffiliatedGroupSchedule` are **absent from the
concordance entirely** — zero rows for either. Both sit at `/Return/ReturnData/`
top level rather than under an `IRS990ScheduleX` node, which is likely why they
were never mapped.

Both are relationship rosters, and both carry a **counterparty EIN on 100% of
rows** — better identifier coverage than most tables that *are* published.

Extracted directly from `EFILE2023.duckdb` / `EFILE2013.duckdb`:

| source | TY2023 rows | filers | distinct counterparties |
|---|---|---|---|
| `AffiliateListing/AffiliateListingGrp` | 3,903 | 138 | 3,466 |
| `AffiliatedGroupSchedule/AffiliatedScheduleGrp` | 2,321 | 240 | 622 |
| (same, TY2013) | 1,070 / 652 | 99 / 121 | 1,040 / 339 |

`AffiliateListing` is the group-return roster: name, EIN, name control, full
address, filed by the parent of a group ruling. `AffiliatedGroupSchedule` is the
Schedule C Part II-A affiliated-group lobbying table — member EIN, name, address
and the lobbying split (direct, grassroots, nontaxable, share of excess
expenditure). That second one is an **advocacy coalition roster**, and nothing
else on the 990 names coalition members with identifiers.

Volumes are small, but 100% EIN coverage makes them unusually clean edges, and
they are structurally different from Schedule R: a group-ruling roster and a
lobbying coalition are not related-organization disclosures.

Working extraction SQL exists at `~/Documents/ef2/aff-2023.R` and
`schedc-2023.R`, handling both the pre- and post-2013 element spellings.

**Action:** add both to the concordance with `rdb_table` assignments, then they
flow into published tables through the normal path. Downstream, they become two
new detectors in `superstructure`.

---

## Explicitly NOT ef2 issues

Filed here only to stop them being re-filed as extraction bugs.

- **People in `BusinessName`, organizations in `PersonNm`.** Filer behavior.
  Measured across every affected table; `insider_loans` runs 55% person-shaped
  in its BusinessName slot. ef2 reproduced the filing correctly. Handled by the
  `D2_name_quality` block, which reports the evidence rather than resolving it.
  See `superstructure/dev/DESIGN-DECISIONS.md` §6.
- **`InstitutionalTrusteeInd` disagreeing with name shape.** Form semantics: the
  box means "this seat is held on behalf of an institution", and the filer still
  writes the person occupying it. Agreement is 52% where ticked. Not a data
  error at all.
- **`affiliate_group` rows having no `schema_version`.** By design — those edges
  derive from the BMF, not from a filing, so there is no XSD version to carry.

---

## Local validators — keep or retire

The instruction is to fix source defects upstream, **not** to strip guards that
are independently sound. Judgment per guard:

| Guard | Verdict | Reasoning |
|---|---|---|
| `drop_empty_alters()` | **Keep — generally robust** | Rests on a claim true regardless of cause: a dyad row naming no counterparty is not an edge. Earned its place on a defect unrelated to Schedule R — 1,167 Schedule N Part I rows carrying a fair market value but naming nobody. Not a mask. |
| `dedupe_dyads()` | **Keep — permanently** | Revised after the `SR-P04` diff. Schedule R inflation has two causes: the header collision (EF2-6, fixable here) and source filings carrying tens of thousands of duplicated repeating groups (not fixable here, ever — one TY2012 filing has 32,768 groups for 637 entities). Deduplication is the only possible response to the second, so this is correct handling rather than a workaround, and it should survive the EF2-6 fix. Its mechanism is sound: it dedupes on the full substantive contract and cannot collapse two genuinely distinct relationships. Keep its inflation-ratio message loud. |
| `ensure_table_cols()` | **Keep — generally robust** | Pads a table with columns it is missing for that year. Column availability genuinely drifts across schema versions; this is normal variation, not a defect. |
| `validate_dyad()` / `validate_person()` | **Keep** | Contract assertions about this package's own output. Unrelated to source quality. |

The test worth applying to any future guard: *would this still be correct if the
upstream bug were fixed tomorrow?* `drop_empty_alters()` passes. A part-inference
heuristic for EF2-1 would not — it would become actively wrong.
