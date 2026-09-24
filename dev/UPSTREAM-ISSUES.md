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
> CSVs are **not** yet regenerated — that is Step 6 and is still open, and the
> defect is confirmed present in the shipped files (*Measured in the published
> CSVs*, below).
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

> **TY2010 rebuilt and diffed end to end on 2026-09-17** — 89 of 112 tables
> content-identical, 23 changed, every changed table matching FLATXML ground
> truth, and zero regressions once `ExpenseAccount` was resolved. See
> *TY2010 end-to-end validation* below.

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

### Measured in the published CSVs (2026-09-17)

The fix landed in code on 2026-08-22, but the published CSVs were uploaded
2026-08-11 and still carry the defect. Audited by range-reading the header row
of all 1,792 files in `s3://nccs-efile/public/efile_v2_2/` — 112 tables ×
TY2009–2024, nothing downloaded:

```bash
curl -s -r 0-60000 \
  "https://nccs-efile.s3.us-east-1.amazonaws.com/public/efile_v2_2/<FILE>" | head -1
```

A column counts as foreign when its `<FORM>_<PART>` prefix differs from the
part named in the filename. **13 tables are affected in at least one year:**

| table | years | worst | absorbs |
|---|---|---|---|
| `SR-P01-T01-ID-DISREGARDED-ENTITIES` | 2009–12 | **60 cols** | SR_02, SR_03, SR_04 |
| `SK-P01-T01-BOND-ISSUES` | 2009–12 | **52** | SK_02, SK_03, SK_04 |
| `SH-P05-T01-HOSPITAL-FACILITY` | 2009–12 | **50** | SH_01, SH_06, SH_99 |
| `SR-P02-T01-ID-RLTD-TAX-EXEMPED-ORGS` | 2009–12 | 22 | SR_03 |
| `SK-P02-T01-BOND-PROCEEDS` | 2009–12 | 15 | SK_03 |
| `SD-P10-T01-OTH-LIABILITIES` | 2009–12 | 3 | SD_13 |
| `SJ-P02-T01-COMPENSATION-DTK` | 2009–12 | 3 | SJ_03 |
| `SK-P05-T01-PROCEDURE-CORRECTIVE-ACT` | 2010–12 | 3 | SK_06 |
| `SR-P06-T01-UNRLTD-ORGS-TAXABLE-PARTNERSHIP` | 2010–12 | 3 | SR_07 |
| `F9-P08-T01-REVENUE-PROGRAMS` | 2009–12 | 2 | F9_01 |
| `F9-P09-T01-EXPENSES-OTHER` | 2009–12 | 1 | F9_01 |
| `SA-P01-T01-PUBLIC-CHARITY-STATUS` | **2013** | 2 | SA_06 |
| `SH-P05-T00-FAP-COMMUNITY-BENEFIT-POLICY` | **2010–2024** | 1 | SH_01 |

Tables affected per year: 9 (2009), 12 (2010–2012), 2 (2013), then **1 in every
year 2014–2024**.

**Two tables leak past TY2012.** The "TY2009–2012 only" framing holds for the
Schedule R tables of EF2-1 — `SR-P01`, `SR-P02` and `SR-P06` all stop at 2012 —
but it does not hold for EF2-6 as a whole:

- `SA-P01-T01-PUBLIC-CHARITY-STATUS` carries `SA_06_FORM_LINE_REFERENCE` and
  `SA_06_EXPLANATION_TEXT` in **TY2013**. This is the
  `Form990ScheduleAPartIVGrp/ExplanationTxt` capture predicted above, now
  confirmed in a shipped file rather than inferred from the concordance.
- `SH-P05-T00-FAP-COMMUNITY-BENEFIT-POLICY` carries
  `SH_01_CHNA_DESC_RESOURCES_X` in **every year from TY2010 through TY2024**.
  This is the `T00`/`T01` co-location described in Step 4, and it reaches the
  current build — not a legacy-only artifact. `SH-P05-T01` itself is clean from
  TY2013 on.

Step 1 (`RDB_TABLE ==`) fixes both. Step 2 (anchoring) fixes neither: `SA-P01`'s
capture lands on a segment boundary already, and the `T00`/`T01` pair shares one
node.

### TY2010 end-to-end validation (2026-09-17)

First full-year rebuild through the fixed path, diffed table by table against the
published CSVs. Method: `download_s3_database(2010, version = "efile_v2_2")`,
then `extract_csv_tables(wd, years = 2010)` — the real entry point, not a
replica of its loop — then all 112 tables compared against
`s3://nccs-efile/public/efile_v2_2/*-2010.CSV`.

Both inputs were byte-verified against S3 before use. Build time was **1.2
minutes** against a local copy of the database.

**Result: 89 of 112 tables content-identical, 23 changed, and — after resolving
`ExpenseAccount` (below) — 0 regressions.**

"Content-identical" here means set equality in both directions (`EXCEPT` each
way), not merely matching row counts.

| table | rows | filings | cols |
|---|---|---|---|
| `SR-P01-T01-ID-DISREGARDED-ENTITIES` | 297,907 → 11,335 (−96.2%) | 37,996 → 3,916 | 93 → 34 |
| `SH-P05-T01-HOSPITAL-FACILITY` | 36,824 → 4,422 (−88.0%) | 2,475 → 2,475 | 127 → 33 |
| `SR-P06-T01-UNRLTD-ORGS-TAXABLE-PARTNERSHIP` | 2,116 → 197 (−90.7%) | 1,671 → 119 | 35 → 31 |
| `SD-P10-T01-OTH-LIABILITIES` | 193,113 → 106,645 (−44.8%) | 74,791 → 53,434 | 23 → 19 |
| `F9-P08-T01-REVENUE-PROGRAMS` | 283,207 → 196,243 (−30.7%) | 123,025 → 86,018 | 25 → 23 |
| `F9-P09-T01-EXPENSES-OTHER` | 607,830 → 492,348 (−19.0%) | 123,025 → 116,010 | 24 → 22 |
| `SR-P02-T01-ID-RLTD-TAX-EXEMPED-ORGS` | 276,253 → 231,011 (−16.4%) | 35,180 → 34,126 | 57 → 35 |
| `SK-P01-T01-BOND-ISSUES` | 9,108 → 8,959 | 5,241 → 5,229 | 68 → 27 |
| `F9-P07-T01-COMPENSATION` | 2,081,865 → **2,082,149** | unchanged | 38 → **42** |

`F9-P07-T01-COMPENSATION` again **gains** the four `F9_07_COMP_DTK_EXPL_*`
columns and 284 rows with them — the same missing-header fix seen at 501 rows in
TY2012.

### Ground-truth check — every changed table, not just Schedule R

For each of the 23 changed tables, the rebuilt filing count was compared against
the filings that genuinely own data for that table in `FLATXML`
(`count(DISTINCT OBJECTID) WHERE TYPE='terminal' AND RDB_TABLE = <table>`):

- **23 of 23 match exactly.**
- **0 tables invented a filing** absent from the published file.

`SR-P01` is the clearest case. FLATXML holds exactly **3,916** filings with
genuine Part I data and the rebuild has exactly 3,916. The published file's
extra 34,080 filings are fully accounted for by the unanchored match: Part II
contributes 34,126 filings, Part III 6,269, Part IV 11,039. The dropped filings
never had Part I data at all.

### The 56 apparently-own-part columns are re-routed, not lost

A prefix check flags 56 dropped columns whose `<FORM>_<PART>` prefix matches
their own table — alarming until resolved, because a prefix cannot distinguish
`T00` from `T01` within one part. Every one lands in its correct destination:

| from | columns | to (per concordance) | present in rebuild |
|---|---|---|---|
| `SH-P05-T01-HOSPITAL-FACILITY` | 36 | `SH-P05-T00-FAP-COMMUNITY-BENEFIT-POLICY` | 36 of 36 |
| `SH-P05-T01-HOSPITAL-FACILITY` | 8 | `SH-P05-T02-NON-HOSPITAL-FACILITY` | 8 of 8 |
| `SG-P02-T01-FUNDRAISING-EVENTS` | 11 | `SG-P02-T00-FUNDRAISING-EVENTS` | 11 of 11 |
| `SA-P01-T01-PUBLIC-CHARITY-STATUS` | 1 | `SA-P01-T00-PUBLIC-CHARITY-STATUS` | 1 of 1 |

**Columns genuinely lost: 0.** This is Step 4 resolving exactly as predicted.

### `SK-P05-T01` rebuilds to zero rows, and that is correct

Step 3's duplicate header entry, now confirmed against data. All **4,953**
TY2010 terminal cells matching `Form990ScheduleKPartV` carry
`RDB_TABLE = SK-P06-T99-SUPPLEMENTAL-INFO`; **none** map to `SK-P05-T01`. The
published table's 2,096 rows were therefore 100% `SK-P06`'s rows, and the
concordance's 5 `SK-P05-T01` xpaths match nothing in TY2010 filings.

The empty-but-headed CSV is faithful. Decide before republishing whether
consumers should receive a zero-row file or none at all.

### `ExpenseAccount` — found, diagnosed, and resolved (2026-09-17)

The first TY2010 rebuild dropped 14 non-concordance stray columns. **13 are
entirely empty** (3,363 cells, zero populated) and dropping them is pure
cleanup. The fourteenth was not: `ExpenseAccount`, **114 cells, all 114
populated, across 59 filings**, in `F9-P07-T01-COMPENSATION-HCE-EZ`.

**The cause was not what EF2-7 assumed.** The xpath is *already* in the live
concordance:

```
/Return/ReturnData/IRS990EZ/CompensationOfHighestPaidEmpl/ExpenseAccount
  -> F9_07_COMP_DTK_EXP_ACCT_HCE  ->  F9-P07-T01-COMPENSATION-HCE-EZ
```

So this was never a concordance coverage gap. It is **staleness in two places**,
and the distinction matters for every future republish:

1. `get_concordance()` defaults to `gh = TRUE`, fetching GitHub master live.
   The **packaged** copy shipped in `data/concordance.rda` had 6,863 rows against
   master's 6,864 — and that single missing row was exactly this xpath. Anyone
   running `gh = FALSE` got the older mapping.
2. More importantly, **`RDB_TABLE` is a materialized column in `FLATXML`**,
   assigned at flatten time. The published TY2010 archive was built before the
   concordance gained this entry, so its stored `RDB_TABLE` is empty for these
   cells and `VARIABLE_NAME` fell back to the raw element name. **Updating the
   concordance alone does not reach an already-built database.**

Point 2 is the one that bites: any table whose `rdb_table` assignment changed
upstream after a database was built will silently disagree with the concordance
until that year is re-flattened. Selection on `RDB_TABLE` is still correct —
it is the stored value that is stale, not the strategy.

**Measured split of the TY2010 orphan population** (terminal cells with no
`RDB_TABLE`), joined against live master:

| status | cells | populated | distinct xpaths |
|---|---|---|---|
| genuinely absent from the concordance | 100,959 | 24,216 | 121 |
| **in the concordance — stored value is stale** | **114** | **114** | 1 |

So EF2-7's larger finding stands: ~24k populated values in ~121 xpaths really
are unmapped and reach no published table. Only `ExpenseAccount` was a
staleness artifact — but it was the only one of the two populations that the old
header regex swept into a published file, which is why it was the only
regression.

**Resolution, applied and verified:**

- Added the xpath to `inst/extdata/concordance.csv` (one row) and regenerated
  `data/concordance.rda`, bringing the packaged copy to master's 6,864 rows.
  The two now differ in nothing.
- Backfilled `RDB_TABLE` / `VARIABLE_NAME` on those 114 cells in the local
  TY2010 database — what re-flattening would produce for them — and rebuilt.

Result, against the published CSV:

| | published | rebuilt |
|---|---|---|
| column | `ExpenseAccount` | `F9_07_COMP_DTK_EXP_ACCT_HCE` |
| populated values | 114 | **114** |
| rows / columns | 45,106 / 29 | 45,106 / 29 |

`(OBJECTID, value)` set difference is **0 in both directions** — every value
survives on the same filing, under its proper concordance name. The rename still
shows as a dropped column in a naive header diff; it is a rename, not a loss.

**With this applied, no TY2010 table is worse than what is published.** 89
content-identical, 23 improved, 0 regressions.

**For the republish:** re-flatten each year rather than re-extracting from the
existing archives, or apply the same backfill. Re-extraction alone inherits
whatever `RDB_TABLE` the archive was built with.

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

Affected years are **TY2009-2012 for most tables, but not all** — see *Measured
in the published CSVs* above. The republish list is 13 tables, of which two
extend past the legacy window:

- `SA-P01-T01-PUBLIC-CHARITY-STATUS` — TY2013
- `SH-P05-T00-FAP-COMMUNITY-BENEFIT-POLICY` — TY2010 through **TY2024**

Every other affected table is confined to TY2009-2012. Do not scope the
republish to the legacy years alone; `SH-P05-T00` needs all 15 of its years
regenerated, TY2024 included.

Regenerate and diff against the published CSVs before replacing them --
`SR-P04-2012` was diffed this way and turned out to be faithful, so do not
assume a table is corrupt merely because it appears in the audit.

A cheap post-republish check, no download required: range-read the header row of
each regenerated file and confirm no column's `<FORM>_<PART>` prefix differs
from the table's own part.

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

> **RESOLVED 2026-09-17, and the diagnosis above was wrong on one point.**
> `ExpenseAccount` was **not** missing from the concordance. GitHub master
> already maps
> `/Return/ReturnData/IRS990EZ/CompensationOfHighestPaidEmpl/ExpenseAccount`
> to `F9_07_COMP_DTK_EXP_ACCT_HCE` / `F9-P07-T01-COMPENSATION-HCE-EZ`. What was
> stale was (a) the **packaged** copy in `data/concordance.rda`, 6,863 rows
> against master's 6,864 — that one row — and (b) the **materialized
> `RDB_TABLE` column** in the published archives, written at flatten time before
> the entry existed. Both are now fixed for TY2010 and verified: all 114 TY2010
> values survive under the proper variable name, `(OBJECTID, value)` set
> difference 0 in both directions. See EF2-6, *`ExpenseAccount` — found,
> diagnosed, and resolved*.
>
> **This does not weaken the rest of EF2-7.** Joining the TY2010 orphan cells
> against live master splits them cleanly:
>
> | status | cells | populated | xpaths |
> |---|---|---|---|
> | genuinely absent from the concordance | 100,959 | 24,216 | 121 |
> | in the concordance, stored value stale | 114 | 114 | 1 |
>
> The ~24k populated values in 121 unmapped xpaths are real and still reach no
> published table. Only `ExpenseAccount` was staleness — and only it regressed,
> because it was the only one of the two populations the old header regex swept
> into a published file.
>
> **The general lesson is the one to carry forward:** `RDB_TABLE` is written
> into `FLATXML` at flatten time, so a concordance change never reaches an
> existing archive. Re-extracting from a published database inherits whatever
> mapping that database was built with. Republishing must re-flatten, or
> backfill `RDB_TABLE` for xpaths whose assignment changed since the build.

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

## EF2-9 — `SA-P00-T00-HEADER` publishes a header-only file in all 16 years

`SA-P00-T00-HEADER` has **zero rows in every year, TY2009–2024**, and unlike
every other empty table in the extract, no schema window explains it. The table
has exactly one xpath:

```
/Return/ReturnData/IRS990ScheduleA/RelationshipSchedule/NameOfOrganization/BusinessNameLine1
```

Its `versions` field is **empty** and `latest_version = NA`.
`RelationshipSchedule` appears nowhere else in the concordance — no versioned
sibling, no alternate spelling, no `*Grp` successor. A one-xpath table whose
only xpath matches no schema version can never populate, and 16 years of zero
row counts are the empirical confirmation.

### Confirmed in the published CSVs (2026-09-17)

All 16 published files are **207-byte header-only files**, byte-identical across
years:

```bash
curl -sI "https://nccs-efile.s3.us-east-1.amazonaws.com/public/efile_v2_2/SA-P00-T00-HEADER-2019.CSV"
# Content-Length: 207
```

| year | Content-Length | data rows |
|---|---|---|
| 2009, 2013, 2019, 2024 (spot-checked) | 207 | 0 |
| (for scale) `SA-P01-T00-…-2019.CSV` | 113,893,092 | — |

The header line is the 16 `KEYS` columns and nothing else — the variable the
table exists to carry, `SA_00_NAME_ORG_L1`, is not even a column, because
`build_table()`'s `new.order` resolves to nothing when no row matches.

### Not the same thing as the `-P99-` tables

Several other tables are empty for long stretches, and those are **correct** —
leave them alone. From the NCCS row-count extract
(`COUNT-OF-ROWS-BY-TABLE-AND-FORMTYPE-EFILE_V2_1.csv`, 112 tables × 16 years =
1,792 cells): 94 zero cells across 12 tables, of which **93 are explained by
schema-version coverage**:

| table | schema span | zero years |
|---|---|---|
| `SA-P04-T00-SUPPORT-ORGS` | 2014–2016 | 2009–2013 |
| `SA-P05-T00-SUPPORT-ORGS` | 2014–2023 | 2009–2013 |
| `SD-P99-T00-RECONCILIATION-NETASSETS` | 2009–2011 | 2012–2024 |
| `SF-P99-T00-FRGN-ORG-GRANTS` | 2009–2011 | 2012–2024 |
| `SI-P99-T00-GRANTS-US-ORGS-GOVTS` | 2009–2011 | 2012–2024 |
| `SN-P99-T00-LIQUIDATION-TERMINATION-DISSOLUTION` | 2009 only | 2010–2024 |
| `SH-P99-T00-FAP-COMMUNITY-BENEFIT-POLICY` | 2010–2015 | 2009, 2016–2024 |
| `SF-P04-T00-FRGN-INTERESTS` | 2010–2016 | 2009 |
| `SH-P05-T00-FAP-COMMUNITY-BENEFIT-POLICY` | 2010–2023 | 2009 |
| `SH-P05-T02-NON-HOSPITAL-FACILITY` | 2010–2016 | 2009 |
| `SK-P05-T01-PROCEDURE-CORRECTIVE-ACT` | 2011–2016 | 2009 |
| **`SA-P00-T00-HEADER`** | **none** | **all 16** |

The `-P99-` tables are not form parts at all; they are holding pens for the
**pre-2012 flat xpath spellings** (`/IRS990ScheduleD/TotalRevenue`, no part
node). That content moved to `Form990ScheduleDPartXI/...` and now lands in
`SD-P11`/`SD-P12`, so the legacy table went permanently empty when the form
changed. That is the extract being faithful, not a defect.

Note the `versions` labels are **schema years, not tax years**, so the ±1 offset
at `SK-P05` — span starts 2011v*, TY2010 is nonzero — is expected and not
evidence of anything.

### One check before acting

Everything above is concordance metadata plus published row counts. Neither
proves the element is absent from the filings themselves, only that nothing ever
reached the table. Confirm against `FLATXML` in any one year:

```sql
SELECT COUNT(*) FROM FLATXML WHERE XPATH LIKE '%RelationshipSchedule%';
```

Zero there means the xpath is a concordance entry for a node that never
shipped. Nonzero would mean the opposite and a much more interesting defect —
data present in the XML and dropped on the floor.

**Answered 2026-09-23: zero in every year.** The xpath reports in
`xpath_reports/` cover all of `FLATXML` for TY2009–2024. `RelationshipSchedule`
appears only in `ALL-XPATHS.csv`'s concordance columns and has no occurrence
count in any year, so the concordance lists a node that no filing ever used.
Proceed with the concordance fix.

**Action if confirmed:** fix it in the concordance, not in the build. Either
remove the row — which retires the table, 112 → 111 — or, if a real Schedule A
node was intended, correct the xpath to that node. Do **not** special-case the
table out of the build loop while leaving the concordance row in place:
`get_table_names()` derives the build list from `rdb_table`, so the row *is* the
table, and a filtered build list would be a second place to keep in sync.

**Blast radius:** nothing downstream breaks — any consumer reading this table
has always read an empty file, so there is no analysis to revisit. The cost is
16 published files that advertise a Schedule A header table and deliver none,
and one phantom entry in the table inventory that anyone auditing coverage has
to rule out by hand.

---

## EF2-10 — `extract_csv_tables()` crashes intermittently on a full-year build

Not a data defect, and not a defect in what the package produces — every table
this crash interrupted was rebuilt and verified. Recorded here, like EF2-5,
because it is a property of this package's own tooling that anyone rebuilding
the panel will hit, and because the obvious explanation for it is **wrong**.

**The R process dies mid-build with no R-level error.** No condition, no
traceback, nothing `tryCatch()` can intercept — on the first occurrence the
shell reported `Segmentation fault`, which places the fault in compiled code
(the `duckdb` R client's native layer), not in any R in ef2.

### Observed rate

Building TY2009–2024 to CSV + Parquet on 2026-09-17 and 2026-09-21, the entry
point was invoked 14 times and died twice:

| attempt | outcome |
|---|---|
| TY2009, TY2010, TY2011 | completed |
| **TY2012 (2026-09-17)** | **died after 61 of 66 `T00` tables** |
| TY2012 (rerun 2026-09-21, deliberate reproduction) | completed, 2.19 min |
| **TY2016 (2026-09-21)** | **died ~20 s in, during the `T00` phase** |
| TY2017–TY2024 | completed, all eight |

No pattern in year, database size, or position in the build. TY2012 died late
and TY2016 died almost immediately; the largest databases (TY2020–TY2023,
~25 GB each) all completed. TY2012 **succeeded on re-run with no change to code
or data**, which is the single most important fact here: the failure is not
reproducible.

### Memory accumulation is ruled out

The first occurrence looked like accumulated session state — 61 tables into one
long-lived R process. **That explanation is wrong.** Re-running the identical
TY2012 build while sampling the process every 2 s:

| point in run | working set |
|---|---|
| peak, during `T00` (~44 tables) | **27.9 GB** |
| **at 122 files — where the original run died** | **~11 GB** |
| settled through the `T01` phase | ~9.5 GB |

Memory rises, peaks, and then *falls*. It does not accumulate across the build,
and at the exact point of the original failure the process was well past its
peak with ~96 GB free on a 127.5 GB machine. Sample trace kept at
`EFILE_BUILD_SEPT_2026/experiment_2012/samples.tsv`.

**Do not re-derive this.** Accumulation, table-specific data, and OS-level
memory exhaustion have all been checked and none of them explains it:

- *A pathological table.* No. `SM-P01-T00-NONCASH-CONTRIBUTIONS`, the table
  TY2012 died on, is 136,056 cells over 18,953 filings and 98 variables, with a
  maximum of **1** cell per `(OBJECTID, VARIABLE_NAME)` — no duplicate-driven
  pivot expansion. It and the four tables after it each build in **under 4
  seconds** from a fresh process.
- *Out of memory.* No. See above.
- *Session length.* No. TY2016 died 20 seconds in.

### What is still unknown

The cause. Also, for the TY2016 occurrence, the **exit status and signal were
not captured**, so it is not even established whether that one was a segfault,
a different signal, or a silent non-zero exit. The driver now records both
(see below), so a third occurrence is diagnosable.

### Mitigation, not a fix

`dev/run_efile_build.sh` tries `extract_csv_tables()` first — it is the
documented entry point and worth exercising — and falls back to rebuilding **15
tables at a time in short-lived processes**, resuming from whichever outputs
already exist on disk. A crash then costs one batch instead of a year.

Resume is keyed on files present, not on a counter, so it is correct after a
hard kill. Both build routes call the same `build_table()` / `build_rdb_table()`
with the same arguments — `extract_csv_tables()` is a `purrr::walk` over exactly
those calls — so output does not depend on which route ran.

This bounds the damage. It does not address the cause, and it should not be
mistaken for having done so.

### Consequence for the data: none

TY2009–2024 rebuilt to CSV + Parquet, **1,792 pairs, all verified byte-equal by
`verify_table_output()`, zero warnings across all 16 years**. Both crashes cost
progress, not correctness. TY2012 and TY2016 — the two interrupted years — carry
the same 112/112 verification as the other fourteen.

---

## EF2-11 — filings with a prefixed `irs:` namespace lose their keys

Found 2026-09-23 while running `process_xpaths()` over the September 2026 build
(`EFILE_BUILD_SEPT_2026`, TY2009–2024).

A few filings put the elements under a **prefixed** namespace, not the default
one:

```xml
<irs:Return xmlns="http://www.irs.gov/efile" xmlns:irs="http://www.irs.gov/efile" ...>
  <irs:ReturnHeader>
```

`xml2::xml_ns_strip()` leaves the `irs:` prefix in place. In the build databases:

- **`XPATH` and `XPATH2` both keep the prefix** (`/irs:Return/irs:ReturnHeader/...`),
  so no row matches the concordance: `RDB_TABLE` is blank and `VARIABLE_NAME`
  falls back to `irs:ReturnTs` and similar. These filings reach no published table.
- **`KEYS` is blank.** `ORG_EIN`, `TAX_YEAR`, `RETURN_TYPE` and the tax period are
  all NULL. Only `VERSION` and `URL` are populated.

41 filings across the whole panel, plus one `/efile:` variant:

| TY | 2017 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 |
|---|---|---|---|---|---|---|---|
| filings | 1 | 1 | 2 | 13 | 12 | 9 | 3 |

They add **1,051 junk xpaths** to the xpath reports, which is 12% of all distinct
xpaths but comes from 0.001% of filings.

**What current code does.** `flatten_xml()` already runs
`gsub("irs:", "", ...)` and `gsub("efile:", "", ...)` on `XPATH2`. The build
databases still contain prefixed `XPATH2`, so whatever produced them did not apply
that step. Re-flattening one of these filings with current code
(`202301719349301665_public.xml`) gives a clean `XPATH2`, and 265 of its 311
rows map to a table. **`get_keys()` still returns NA** for `ORG_EIN` and
`TAX_YEAR`, because its xpaths do not see through the prefix. So the key half of
this defect is still live.

In every year, the count of NULL-`ORG_EIN` rows in `KEYS` equals the count of
prefixed filings, except TY2024 (5 vs 3). EF2-2 may be the same mechanism;
check its two OBJECTIDs against this list.

**Fix:** strip the prefix from the document before `get_keys()` runs, not only
from the xpath strings. Rebuilding these ~41 filings is enough; no full rebuild
is needed.

---

## EF2-12 — real filing data sits in XML attributes and reaches no published table

The IRS stores some filed values as **XML attributes** rather than element text.
`get_attr_df()` captures all of them into `ATTRIBUTES` (`//*[@*]`, one row per
attribute), so nothing is lost at parse time — but `ATTRIBUTES` feeds no table,
and none of these values appear in any published CSV or Parquet file.

Same class as EF2-7 and EF2-8: real filed data that no published table exposes.

### What is in `ATTRIBUTES`

| year | rows | filings | attrs/filing | distinct names |
|---|---|---|---|---|
| 2012 | 6.67 M | 273,438 | 24.4 | 16 |
| 2018 | 9.89 M | 420,826 | 23.5 | 16 |
| 2024 | 10.22 M | 456,170 | 22.4 | 20 |

About **93% of rows are XML plumbing** with no analytic content:
`referenceDocumentId` (3.87 M rows in TY2024), `documentId` (2.07 M),
`referenceDocumentName`, `documentName`, the `xmlns:*` family, `schemaLocation`,
`documentCnt`. `binaryAttachmentCnt` is **0 on all 456,170 TY2024 filings** — a
dead field. Leave all of it alone.

`returnVersion` is **already captured**: `get_keys()` reads it as `VERSION`, and
joining `KEYS.VERSION` against the attribute in TY2024 matches 1:1 across all
five schema versions. Nothing to do there either.

### The part that is real data

Panel-wide filing-year counts, TY2009–2024:

| attribute (legacy / current) | node | filing-years | what it is |
|---|---|---|---|
| `typeOf501cOrganization` / `organization501cTypeTxt` | `Organization501cInd` | **1,457,404** | 501(c) subsection number |
| `softwareId`, `softwareVersionNum` | various | 2,180,222 | e-file software vendor + version |
| `contributionsReportedOnLine1a` / `fndrsngEventContriPrevRptAmt` | `FundraisingGrossIncomeAmt` | 291,097 | **dollar amount** |
| `note` / `methodOfAccountingOtherDesc` | `MethodOfAccountingOtherInd` | 74,324 | "Other" accounting method text |
| `accountingPeriodChangeCd`, `...ApprvCd` | `IRS990`, `IRS990EZ` | 21,709 | period change + approval basis (TY2020+) |
| `amountOfInterest` / `interestAmt` | `NECTFilingForm990Ind` | 297 | negligible |

**None of the ten appears in the concordance.** The only substring hits for
`note` are unrelated footnote checkboxes (`F9_04_REP_FOOTNOTE_FIN48_X` and
siblings), not this attribute.

### The 501(c) subsection is the significant one

The published header table records **that** an organization is a 501(c) other
than (3), and never **which**:

| | TY2012 | TY2024 |
|---|---|---|
| `F9_00_EXEMPT_STAT_501C_X` ticked | 68,570 | 104,296 |
| subsection present in `ATTRIBUTES` | **68,570** | **104,296** |
| published column holding the number | **none** | **none** |

An exact 1:1 both years. The TY2024 distribution runs across 25 subsections and
is exactly what it should be — (c)(6) trade associations 27,792, (c)(4) social
welfare 20,564, (c)(7) social clubs 14,846, (c)(5) labor 14,822, out to (c)(29).
A consumer today cannot separate a trade association from a labour union from a
social club, although the filing says so.

`fndrsngEventContriPrevRptAmt` is genuinely money, not a flag: TY2024 has 36,276
filings carrying it, 7,643 non-zero, median non-zero **$14,590**, max $9.53 M,
**$199.9 M** in total.

`methodOfAccountingOtherDesc` is a partial loss rather than a total one. The
published `F9_12_FINSTAT_METHOD_ACC_OTH` is populated for 837 filings in TY2012
and 1,296 in TY2024, against 3,328 and 5,782 in `ATTRIBUTES` — the attribute is
the fuller source by roughly 4x.

### `get_keys()` does not capture the subsection — but the mechanism is already there

Checked against both the source and the built databases: `get_keys()` returns 16
variables (`EIN2`, `OBJECTID`, `ORG_EIN`, `ORG_NAME_L1`, `ORG_NAME_L2`,
`RETURN_AMENDED_X`, `RETURN_GROUP_X`, `RETURN_PARTIAL_X`, `RETURN_TAXPER_DAYS`,
`RETURN_TIME_STAMP`, `RETURN_TYPE`, `TAX_PERIOD_BEGIN_DATE`,
`TAX_PERIOD_END_DATE`, `TAX_YEAR`, `URL`, `VERSION`) and none is the 501(c)
subsection. The `KEYS` table in every published archive carries exactly those 16
columns.

**But `VERSION` is itself an attribute** — `xml_attr(doc, 'returnVersion')` — so
there is already precedent for an attribute becoming a first-class variable.

And `retrieve_xml()` needs **no modification** to read one. It is
`xml_text(xml_find_all(doc, path))`, and an attribute xpath resolves through it
unchanged. Verified against a live TY2024 filing
(`202512129349300511_public.xml`, expected `9`):

```r
P <- paste( "//Organization501c/@typeOf501cOrganization",
            "//Organization501cInd/@organization501cTypeTxt", sep = "|" )
retrieve_xml( doc, P )      # "9"
```

The both-spellings pipe is the same idiom `get_keys()` already uses everywhere,
and it handles the rename described below in one expression.

**One trap, and it is EF2-11's trap.** This only works on a namespace-stripped
document. IRS filings carry a default namespace
(`d1 <-> http://www.irs.gov/efile`), and every unprefixed xpath returns nothing
until `xml2::xml_ns_strip()` runs — including the existing `KEYS` xpaths. The
pipeline already strips at `R/03_flatten_xml.R:139`, so anything added inside
`get_keys()` is fine. Ad-hoc scripts that call `read_xml()` and query directly
get `NA` for *everything*, silently; that is a namespace error, not a missing
value. (Confirmed the hard way while testing this: a live filing returned `NA`
for the attribute **and** for `//Return/ReturnHeader/TaxYr`, until the strip.)

**EF2-11 is the same failure class**, one step further out: on the ~41 filings
that use a *prefixed* `irs:` namespace, `xml_ns_strip()` leaves the prefix in
place and `get_keys()` returns NA for `ORG_EIN` and `TAX_YEAR`. Any attribute
added to `get_keys()` will be blank on exactly those filings too, for exactly
that reason. Fixing EF2-11 fixes it here as well; do not treat the two
separately.

### All of these renamed at the TY2012/TY2013 boundary

| legacy, TY2009–2012 | current, TY2013–2024 |
|---|---|
| `typeOf501cOrganization` | `organization501cTypeTxt` |
| `contributionsReportedOnLine1a` | `fndrsngEventContriPrevRptAmt` |
| `note` | `methodOfAccountingOtherDesc` |

Clean switchover, no overlap year. The same boundary drives EF2-6. Any mapping
that carries only one spelling breaks the panel at 2013 exactly as Schedule A
did.

### Recommended, in order

1. **501(c) subsection.** Largest coverage, unambiguous semantics, and it turns
   an existing binary flag into a 25-level classification. `KEYS` is the natural
   home — it is filing-level, one value per return, and sits beside `VERSION`,
   which arrived the same way.
2. **`fndrsngEventContriPrevRptAmt`** — a dollar figure on a 990-EZ line.
3. **`softwareId` / `softwareVersionNum`** — not filing data, but it supports
   work on filing quality and vendor effects, and belongs with `VERSION`.
4. **`methodOfAccountingOtherDesc`** — worth adding; values normalise easily
   (the top six are spelling variants of "modified cash").
5. **`accountingPeriodChangeCd` / `...ApprvCd`** — low volume, cheap, unambiguous.

**Do not** add `interestAmt` (297 filing-years panel-wide) or anything in the
plumbing bucket. `returnVersion` is already `VERSION`; do not duplicate it.

### Resolved: `ORG_EXEMPT_TYPE` in `get_keys()` (2026-09-24)

Implemented as one coherent string rather than the bare subsection integer:
`"501c2"`…`"501c29"`, `"4947a1"`, `"527"`, or `NA`. A string because `6` is a
501(c) subsection while `4947` and `527` are IRC sections — mixing them in one
numeric column makes sorting, ranges and means silently meaningless, and loses
the `(a)(1)`.

The values match the `TaxStatus` naming in Giving Tuesday's index
(`501c3`, `501c6`, `4947a1`), so the two line up without a translation table.
That was not designed for; it was found afterwards and kept.

Three encodings are reconciled. The (c)(3) checkbox arrives in TY2010; in TY2009
there is no such checkbox and (c)(3) filers write `3` into the subsection
attribute instead — **all 39,633 literal `3` values in the whole panel are
TY2009, and none of them tick a (c)(3) box.** Without harmonising, TY2009 reports
39,633 subsection-3 organizations and every later year reports none, which reads
as a defect rather than as two spellings of one fact.

Verified against 27 real filings across TY2009, TY2012 and TY2024, covering
501(c)(N), 501(c)(3) in both encodings, and 4947(a)(1): 27 of 27 agree with the
databases. 29 unit tests.

### Where the 527 organizations are: not here, and not filtered out either

`F9_00_EXEMPT_STAT_527_X` exists in the concordance, maps to the single xpath
`/Return/ReturnData/IRS990/Form990PartI/Organization527`, and **matches nothing
in any of TY2009–2024** — an EF2-9-class dead variable. Searching raw `XPATH2`
for `527` so an unmapped element could not hide, every hit is one of two other
things, neither of which is the filer's own status:

| element | what it actually asks |
|---|---|
| `IRS990EZ/RelatedOrgSect527OrgInd` → `F9_04_RLTD_ORG_527_X` | are you *related to* a 527 organization? (990-EZ Part V) |
| `IRS990ScheduleC/Section527PoliticalOrgGrp/*` | the 527 organizations the filer *paid* (Sch C Part I-C) |

The coverage arithmetic leaves no room for them either. TY2024: 351,605 (c)(3)
plus 104,296 (c)(other) plus 266 4947(a)(1) plus 3 with no status = 456,170,
exactly the `KEYS` count. The four statuses are perfectly mutually exclusive.

**They are not being filtered out.** Giving Tuesday's index carries only four
`FormType` values across 7.5M rows — `990`, `990EZ`, `990PF`, `990T` — and no
`527`. Its `TaxStatus` column runs `501c3`, `501c2`…`501c29`, `4947a1` and `NA`,
again with **no 527 value anywhere**. So 527 filings are absent from the source
corpus, not dropped during the build.

For context, and *not* verified from these data: §527 political organizations
report to the IRS on Forms 8871 and 8872 through a separate disclosure system,
which is not part of the 990 e-file pipeline. A 527 with $25k+ gross receipts
that is not an FEC-reporting committee can also owe a Form 990/990-EZ; none
appears in this corpus declaring that status, but some could sit among the
`NA`-status filings without saying so.

### 990-PF *is* in the data lake and is dropped by the build

Distinct from the 527 case, and worth not confusing with it. `prep_index()`
defaults to `form.type = c("990", "990EZ")`, and `split_index()` calls it
without overriding that default, so the archives can never contain anything
else. Against the current index:

| FormType | rows in the index | in the ef2 build? |
|---|---|---|
| `990` | 3,965,080 | yes |
| `990EZ` | 2,218,958 | yes |
| `990PF` | **1,201,201** | **dropped** |
| `990T` | **114,313** | **dropped** |

1,315,514 filings are excluded by that one default — 990-PF from TY2008 and
990-T from TY2020. `get_keys()` already reads the 990-PF amended-return element,
so the parsing side is partly ready; the exclusion is a batching decision, not a
capability gap. Whether to include them is a scope question for the build, not a
defect.

### Open design question

Adding these to `KEYS` via `get_keys()` is mechanical and needs no new
machinery. Routing them through the **concordance** instead is not: the
concordance maps xpaths to elements, `ATTRIBUTES` records the xpath of the
*node* rather than of the attribute
(`/Return/ReturnData/IRS990/Organization501cInd`, with `attr_name` held
separately), and `RDB_TABLE` is assigned during flattening. Deciding whether
attributes should become synthetic terminal rows in `FLATXML` — and so reachable
by the ordinary table machinery — is a modelling choice, not a patch, and should
be made deliberately rather than inferred from whichever route is easiest.

Supporting detail: `EFILE_BUILD_SEPT_2026/attr_analysis/attr_names_by_year.csv`
and `attr_panel_coverage.csv`.

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
