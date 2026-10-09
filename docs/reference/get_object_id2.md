# Extract an OBJECTID from a filing URL

Converts an IRS 990 e-file XML URL into a standardized OBJECTID
(prefixed with `OID-`) used as a database key.

## Usage

``` r
get_object_id2(url)
```

## Arguments

- url:

  Character. Full XML URL (vectorised).

## Value

Character OBJECTID.

## Details

The ID is taken from the file name (`<OBJECTID>_public.xml`), so any
host or folder works: GTDC `XmlFiles/`, NCCS `xml/`, and the patch
folders under `xml2/` (e.g. `xml2/v2_3_patch/`). Earlier versions
removed a fixed list of URL prefixes, so a URL from any other folder
produced a key that still contained the URL.

## Examples

``` r
get_object_id2("https://nccs-efile.s3.us-east-1.amazonaws.com/xml/202220139349301207_public.xml")
#> [1] "OID-202220139349301207"
```
