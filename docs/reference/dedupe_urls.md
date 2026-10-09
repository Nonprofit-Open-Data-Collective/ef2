# Drop repeated filings from a build list

An efiler index can list the same return more than once. The Giving
Tuesday index re-indexed TY2019-2022 returns in 2025 and kept the
original listings, so 26,448 ObjectIds appear twice with the same URL
(EF2-19). Built from such a list, each copy is downloaded and parsed,
and the filing is stored twice in KEYS, FLATXML and ATTRIBUTES, which
duplicates its rows in every table.

## Usage

``` r
dedupe_urls(urls)
```

## Arguments

- urls:

  Character vector of XML URLs.

## Value

`urls` without repeated filings, in the original order.

## Details

Filings are identified by ObjectId (the file name without
`_public.xml`), which also catches one return listed under two URL forms
(e.g. the GT data lake and the nccs-efile mirror). The first URL of each
ObjectId is kept.
