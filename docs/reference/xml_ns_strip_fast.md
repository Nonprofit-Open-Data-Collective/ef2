# Remove default namespaces from a document (fast xml_ns_strip)

Same result as
[`xml2::xml_ns_strip()`](http://xml2.r-lib.org/reference/xml_ns_strip.md),
which removes `xmlns` from every element that has a default namespace
*in scope*. Every element inherits the root's namespace, so it touches
every element, and each removal also walks the element's subtree:
quadratic in document size (642 s for a 31.5 MB 990-PF return with
505,796 elements). Removing the declaration from the topmost elements
that carry it clears the whole subtree in one pass; the loop repeats in
case a nested element redeclares a different default.

## Usage

``` r
xml_ns_strip_fast(x)
```

## Arguments

- x:

  An `xml2` document.

## Value

`x`, invisibly (modified in place, like
[`xml2::xml_ns_strip()`](http://xml2.r-lib.org/reference/xml_ns_strip.md)).
