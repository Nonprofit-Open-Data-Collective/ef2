# Extract files from a zip whose central directory is damaged

Last resort in
[`extract_zip_files()`](https://nonprofit-open-data-collective.github.io/ef2/reference/extract_zip_files.md).
Some IRS zips cannot be opened by index; reading them front to back from
the local file headers works for entries compressed with ordinary
Deflate. The zip is piped through libarchive's `bsdtar` in streaming
mode and only the wanted files are extracted. **On Deflate64 entries
bsdtar writes zero-filled files**, which is why the caller validates the
output.

## Usage

``` r
stream_unzip(zf, files, dest)
```

## Arguments

- zf:

  Path to the zip file.

- files:

  File names (no folder) to extract.

- dest:

  Folder to put them in, without the zip's internal folders.

## Value

The base names of the files extracted.

## Details

Needs `bsdtar`. It ships with Windows 10+ as
`%SystemRoot%\System32\tar.exe`, and with macOS as `tar`. GNU tar cannot
read zip files. A large zip takes a few minutes, because it is read in
full.
