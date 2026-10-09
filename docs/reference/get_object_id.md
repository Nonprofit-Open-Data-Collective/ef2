# Extract an OBJECTID from a filing URL

Parses the unique object ID from an IRS 990 e-file XML URL and prefixes
it with `OID-`.

## Usage

``` r
get_object_id(url)
```

## Arguments

- url:

  Character. Full XML URL.

## Value

Character scalar OBJECTID (e.g. `"OID-202301529349200315"`).

## See also

[`get_object_id2()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_object_id2.md),
which this now matches: both take the ID from the file name, so URLs on
any host or folder work.

## Examples

``` r
base <- "https://gt990datalake-rawdata.s3.amazonaws.com/EfileData/XmlFiles/"
get_object_id(paste0(base, "202301529349200315_public.xml"))
#> [1] "OID-202301529349200315"
# "OID-202301529349200315"
```
