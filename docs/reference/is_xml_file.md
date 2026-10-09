# Is a file an XML document (and not blank or zero-filled)?

Is a file an XML document (and not blank or zero-filled)?

## Usage

``` r
is_xml_file(path)
```

## Arguments

- path:

  Path to a file.

## Value

`TRUE` if the first non-BOM, non-whitespace byte is `<`.
