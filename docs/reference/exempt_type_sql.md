# SQL deriving each filing's tax-exempt status as one string

One row per 990 / 990-EZ filing that declares a status, with
`F9_00_ORG_EXEMPT_TYPE` set to `"501c2"` … `"501c29"`, `"4947a1"` or
`"527"`. Reads only `FLATXML` and `ATTRIBUTES`, so it works on any built
archive without re-parsing XML. See EF2-12.

## Usage

``` r
exempt_type_sql(year)
```

## Arguments

- year:

  Integer tax year; tables are read as `EFILE<year>.FLATXML` and
  `EFILE<year>.ATTRIBUTES`.

## Value

A character string of SQL.

## Details

Three encodings are reconciled:

- 501(c) other than (3): the subsection number is an XML *attribute*
  (`typeOf501cOrganization` TY2009-2012, `organization501cTypeTxt`
  TY2013+), held in `ATTRIBUTES` and in no published table.

- 501(c)(3): a checkbox element from TY2010. TY2009 has no such checkbox
  and (c)(3) filers write `"3"` into the subsection attribute instead,
  so the attribute branch yields `"501c3"` there too.

- 4947(a)(1) and 527: checkbox elements. 527 has never been selected in
  TY2009-2024 and is carried in case a schema ever produces one.

A string rather than an integer, because 4947 and 527 are IRC sections,
not 501(c) subsections. The values match the `TaxStatus` naming in
Giving Tuesday's index.

The `CASE` branches are ordered but never compete: across TY2009-2024 no
filing selects more than one status. A checkbox counts as ticked when it
is present and not an explicit negative (`"0"`, `"false"`, `"n"`,
`"no"`); every observed value is `"X"`. Every path step accepts an
optional `irs:` prefix (EF2-11).

A filing carrying more than one distinct subsection value keeps all of
them, sorted and joined with `";"` (e.g. `"501c4;501c6"`), rather than
having one picked silently (cf. EF2-3). None has been observed in
TY2009-2024.
