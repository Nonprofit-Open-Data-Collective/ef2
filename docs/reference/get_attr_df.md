# Extract all XML node attributes into a tidy data frame

Each attribute is returned as one row with columns: OBJECTID, node_name,
xpath, attr_name, and attr_value.

## Usage

``` r
get_attr_df(doc, url)
```

## Arguments

- doc:

  Parsed XML document (xml2::read_xml()).

- url:

  Source URL of the XML file (used to derive OBJECTID).

## Value

A tidy data frame with one row per attribute.
