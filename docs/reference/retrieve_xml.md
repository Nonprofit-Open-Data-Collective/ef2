# Extract text from XML nodes

Retrieves the text content of all nodes matching an XPath expression.

## Usage

``` r
retrieve_xml(doc, TEMP_VAR)
```

## Arguments

- doc:

  An XML document object (from
  [`xml2::read_xml()`](http://xml2.r-lib.org/reference/read_xml.md)).

- TEMP_VAR:

  Character. XPath expression specifying the nodes to retrieve.

## Value

A character vector of extracted text, or `NA` if no nodes match.

## Examples

``` r
if (FALSE) { # \dontrun{
retrieve_xml(doc, "//Return/ReturnHeader/TaxYr")
} # }
```
