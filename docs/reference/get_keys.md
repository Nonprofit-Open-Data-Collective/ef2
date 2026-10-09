# Get table keys for a single filing

Collects the identifying metadata fields (OBJECTID, EIN, organization
name, tax period, return type/flags, etc.) that key every relational
table built from an IRS 990 e-file document. These are the "RDB keys"
attached to every one-to-one and one-to-many table so that unique tax
filings can be identified, filtered, and linked across tables.

## Usage

``` r
get_keys(doc, url)
```

## Arguments

- doc:

  An XML document object (from
  [`xml2::read_xml()`](http://xml2.r-lib.org/reference/read_xml.md)).

- url:

  Character. Source URL of the filing (stored as `URL` and used to
  derive the `OBJECTID`).

## Value

A named list of key fields for the filing, suitable for coercion to a
one-row data frame:

- EIN2:

  Employer Identification Number formatted as `EIN-XX-XXXXXXX` (see
  [`format_ein()`](https://nonprofit-open-data-collective.github.io/ef2/reference/format_ein.md)).

- OBJECTID:

  Unique filing identifier prefixed with `OID-`, derived from `url` (see
  [`get_object_id()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_object_id.md)).

- ORG_EIN:

  Raw Employer Identification Number digits from the return header.

- ORG_NAME_L1:

  Filing organization name, line 1.

- ORG_NAME_L2:

  Filing organization name, line 2 (if present).

- RETURN_AMENDED_X:

  Logical; `TRUE` if the filing is an amended return (read from the 990,
  990-EZ or 990-PF amended-return element).

- RETURN_GROUP_X:

  Logical; `TRUE` if the filing is a group return for affiliates. Always
  `FALSE` for the 990-EZ and 990-PF, which have no group returns.

- RETURN_PARTIAL_X:

  Logical; `TRUE` if the tax period spans fewer than 360 days
  (partial-year return).

- RETURN_TAXPER_DAYS:

  Number of days in the tax period (end minus begin, plus 1).

- RETURN_TIME_STAMP:

  Timestamp when the return was created/submitted.

- RETURN_TYPE:

  Return type (e.g. `"990"`, `"990EZ"`, `"990PF"`).

- TAX_PERIOD_BEGIN_DATE:

  Tax period begin date.

- TAX_PERIOD_END_DATE:

  Tax period end date.

- TAX_YEAR:

  Tax year covered by the filing.

- URL:

  Source URL of the raw XML filing.

- VERSION:

  IRS schema version of the return (`returnVersion` attribute).

## See also

[`add_keys()`](https://nonprofit-open-data-collective.github.io/ef2/reference/add_keys.md),
which attaches these keys to relational tables.

## Examples

``` r
if (FALSE) { # \dontrun{
doc <- xml2::read_xml(url)
xml2::xml_ns_strip(doc)
get_keys(doc, url)
} # }
```
