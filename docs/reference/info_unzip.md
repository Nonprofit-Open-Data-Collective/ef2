# Extract files with Info-ZIP unzip

Used by
[`extract_zip_files()`](https://nonprofit-open-data-collective.github.io/ef2/reference/extract_zip_files.md)
for Deflate64 zips. Up to 200 names are passed as patterns; above that
the whole zip is extracted (into a temporary folder) and the caller
keeps what it needs.

## Usage

``` r
info_unzip(zf, files, out)
```

## Arguments

- zf:

  Path to the zip.

- files:

  File names (no folder) wanted.

- out:

  Folder to extract into (flattened).
