# Write release notes from a release comparison

Renders a
[`compare_releases()`](https://nonprofit-open-data-collective.github.io/ef2/reference/compare_releases.md)
result as Markdown: a summary, filings by tax year, tables added and
dropped, column changes grouped by table, row-count changes, and
concordance changes.

## Usage

``` r
write_release_notes(
  cmp,
  file = NULL,
  title = cmp$meta$new,
  notes = NULL,
  max_rows = 60
)
```

## Arguments

- cmp:

  A `release_comparison`.

- file:

  Output `.md` path; `NULL` returns the text only.

- title:

  Release name for the heading.

- notes:

  Optional character vector of hand-written context, placed at the top
  under "Notes". The comparison reports what changed; why it changed has
  to come from the build record.

- max_rows:

  Longest list printed per section; longer lists are summarised.

## Value

The Markdown text, invisibly.
