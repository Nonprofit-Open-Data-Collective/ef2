# Identify missing URLs in a given tax year

Compares the filings stored in a DuckDB KEYS table (remote S3 database)
against an index data frame, identifying which filings are missing from
the database.

## Usage

``` r
find_missing_urls(year, index, version = "efile_v2_3", source_db = NULL)
```

## Arguments

- year:

  Integer tax year.

- index:

  Data frame with columns TaxYear and URL.

- version:

  S3 version subfolder under duckdb/ (default "efile_v2_3"). Set to NULL
  or "" to target the unversioned duckdb/ path.

- source_db:

  Optional path to a local `.duckdb` to compare against instead of the
  S3 archive (e.g. a local `EFILEPF<year>.duckdb`).

## Value

Character vector of missing URLs.

## Details

Filings are matched on `OBJECTID`, not on URL. The same filing can be
served from more than one place (GTDC `XmlFiles/`, an NCCS patch folder
under `xml2/`), so matching on URL would add a filing a second time when
its URL changes. If the index lists one filing under several URLs, the
first is returned.
