# Xpaths of every element, in document order

The same result as `xml2::xml_path(xml2::xml_find_all(doc, "//*"))`, in
linear time. libxml2 builds each path by scanning the element's
siblings, which is quadratic when one parent has many children (a 990-PF
grant list with tens of thousands of entries took 4-7 minutes; returns
of 250+ MB would take hours). Here each parent's children are named
once: an element gets `[k]` only when a sibling has the same name, as
libxml2 does.

## Usage

``` r
get_xml_paths(doc)
```

## Arguments

- doc:

  An `xml2` document (namespaces stripped).

## Value

Character vector of xpaths, one per element, in document order.

## Details

Documents with elements still in a namespace after `xml_ns_strip()` (see
EF2-11) fall back to
[`xml2::xml_path()`](http://xml2.r-lib.org/reference/xml_path.md), which
writes the prefixes.
