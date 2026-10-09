# Extract named files from an IRS zip, trying several extractors

IRS zips defeat any single extractor:

- `zip` (miniz) reads ordinary zips. It cannot read the large zip64
  archives (e.g. `2024_TEOS_XML_05A.zip`, 156,237 entries), and it
  cannot read **Deflate64** (method 9), which `2026_TEOS_XML_05B.zip`
  uses.

- Info-ZIP `unzip` reads Deflate64. It warns about the zip64 entry count
  but extracts correctly.

- `bsdtar` in streaming mode reads damaged-index zips that use ordinary
  Deflate. On Deflate64 it **writes zero-filled files without failing**.

So each extractor's output is checked with
[`is_xml_file()`](https://nonprofit-open-data-collective.github.io/ef2/reference/is_xml_file.md),
and files that fail are passed to the next one. Only valid files reach
`dest`.

## Usage

``` r
extract_zip_files(zf, files, dest)
```

## Arguments

- zf:

  Path to the zip.

- files:

  File names (no folder) wanted.

- dest:

  Destination folder.

## Value

A list: `files` (the names extracted) and `method` (the extractors that
contributed, joined with `+`).
