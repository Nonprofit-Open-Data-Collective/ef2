# Flatten a batch of XML filings and write to DuckDB

Sequentially downloads and parses a batch of XML files, flattens them,
and writes results to KEYS, FLATXML, and ATTRIBUTES tables within a
single DuckDB transaction.

## Usage

``` r
batch_flatten(batch, con, ccf, quietly = TRUE)
```

## Arguments

- batch:

  Character vector of XML URLs.

- con:

  Active DBI connection to DuckDB.

- ccf:

  Concordance crosswalk (prepared via prep_concordance()).

- quietly:

  Logical; if FALSE, print per-file progress.

## Value

Invisibly, the number of successfully processed XMLs.
