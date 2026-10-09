# Flatten an IRS 990 XML document to long-form rows

Flatten an IRS 990 XML document to long-form rows

## Usage

``` r
flatten_xml(doc, url, ccf = NULL)
```

## Arguments

- doc:

  An `xml2` document.

- url:

  Source URL for this filing.

- ccf:

  Optional concordance crosswalk (data frame) with columns xpath,
  variable_name, rdb_table.

## Value

Data frame with columns: OBJECTID, ORDER, XPATH, XPATH2, TABLE_HEADER,
TABLE_ID, TYPE, RDB_TABLE, VARIABLE_NAME, VALUE.
