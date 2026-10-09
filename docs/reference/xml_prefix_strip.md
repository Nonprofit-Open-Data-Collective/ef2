# Remove namespace prefixes from element names (EF2-11)

A few returns write every element with a prefix (`<irs:Return>`,
`<irs:ReturnHeader>`, ... and one `efile:` variant). Stripping the
default namespace leaves the prefix, so
[`get_keys()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_keys.md)
finds nothing (KEYS all NA), `XPATH` and `ATTRIBUTES$xpath` carry
`irs:`, and only `XPATH2` is cleaned. This re-parses such a document
with the prefix dropped from every element tag, then strips the default
namespace again, so it is parsed exactly like an unprefixed return.
Documents with no element in a namespace (all but ~0.001% of returns)
are returned unchanged, without re-parsing.

## Usage

``` r
xml_prefix_strip(doc)
```

## Arguments

- doc:

  An `xml2` document, default namespace already stripped.

## Value

The document to use: `doc` itself, or a re-parsed copy.
