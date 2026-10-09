# Read return-header fields from e-file XML documents

Reads the fields a build index needs from each file's `ReturnHeader`,
using the same xpaths as
[`get_keys()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_keys.md)
for `TAX_YEAR`.

## Usage

``` r
read_return_headers(files)
```

## Arguments

- files:

  Character vector of local XML file paths.

## Value

A `data.table` with `OBJECT_ID`, `TaxYear`, `FormType`, `ReturnTs`,
`TaxPeriodBeginDate`, `TaxPeriodEndDate`, `ReturnVersion`, and
`READ_ERROR`.

## Details

`TaxYear` is `TaxYr` (or `TaxYear` in older schemas). When neither is
present it falls back to the year of `TaxPeriodBeginDt`.

A file that cannot be parsed gets a row with `NA` fields and
`READ_ERROR` set to the parser's message, so one bad file does not stop
a run of thousands.
