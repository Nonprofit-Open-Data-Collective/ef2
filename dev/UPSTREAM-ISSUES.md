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

**Hypothesis, not yet confirmed:** `get_table_id()` in `R/99_utils.R` derives
`TABLE_ID` from the *last* bracketed index in the xpath (`tail(matches, 1)`).
For Schedule R the repeating group sits at the part level, so
`Form990ScheduleRPartI[1]` and `Form990ScheduleRPartII[1]` both yield
`TID-00001`. If variables from both parts reach one `pivot_wider()` keyed on
`OBJECTID` + `TABLE_ID`, rows from different parts collide. Worth confirming
before acting on.

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
| `dedupe_dyads()` | **Keep — but it is a safety net, not the fix** | Its mechanism is sound: it dedupes on the full substantive contract, so it cannot collapse two genuinely distinct relationships. But it exists because of EF2-1 and it *does* make pre-2013 data look usable while `row_seq` is quietly destroyed. It must not become the reason EF2-1 stays open. It reports its inflation ratio on every run — keep that message loud. |
| `ensure_table_cols()` | **Keep — generally robust** | Pads a table with columns it is missing for that year. Column availability genuinely drifts across schema versions; this is normal variation, not a defect. |
| `validate_dyad()` / `validate_person()` | **Keep** | Contract assertions about this package's own output. Unrelated to source quality. |

The test worth applying to any future guard: *would this still be correct if the
upstream bug were fixed tomorrow?* `drop_empty_alters()` passes. A part-inference
heuristic for EF2-1 would not — it would become actively wrong.
