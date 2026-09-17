
#' Write a built table to CSV and/or Parquet from a single DuckDB temp table
#'
#' @description
#' Materialises `db_tbl` into a DuckDB temporary table once, then `COPY`s it to
#' CSV, Parquet, or both. Writing both from the same materialised relation is
#' what makes the two outputs consistent: they are two serialisations of one
#' relation, not a text file plus a re-parse of that text file.
#'
#' @details
#' **Why Parquet from the temp table and not from the CSV.**
#' Everything in FLATXML is stored as VARCHAR -- `R/04_write_to_duckdb.R` calls
#' `lapply(df, as.character)` before writing -- so the relation reaching this
#' function is already all-character. Copying it straight to Parquet involves no
#' type inference at any point. Converting the published CSV instead means
#' re-parsing text, and `data.table::fread()` and `read.csv()` both silently
#' cast `ORG_EIN` to integer: 7,969 of 20,000 sampled TY2023 header rows lose a
#' leading zero that way, e.g. `061721946` becomes `61721946`.
#'
#' **The empty-string problem, and why `normalize_empty` defaults to TRUE.**
#' The relation genuinely holds two different blanks. `pivot_wider(values_fill =
#' "")` produces empty strings; the `right_join()` against KEYS produces SQL
#' NULLs. CSV writes these differently -- `""` against a bare empty field -- but
#' no reader distinguishes them on the way back in. DuckDB, `readr` and
#' `read.csv` all return NA for both. Parquet has a real null indicator and so
#' preserves the distinction, which means a faithful Parquet file would *not*
#' agree with its own CSV sibling. In the TY2023 header table that is roughly
#' 12.2 million cells, about 29% of the file.
#'
#' `normalize_empty = TRUE` collapses `''` to NULL in the Parquet output only,
#' reproducing what every CSV reader already does, so the two published formats
#' answer identically. The CSV output stays byte-identical to what the package
#' writes today. Set `normalize_empty = FALSE` to keep the distinction, but only
#' alongside a documented note that the two formats differ by design.
#'
#' @param db_tbl A lazy tibble / table reference to materialise.
#' @param table_name Character table id, e.g. `"F9-P00-T00-HEADER"`.
#' @param year Integer year.
#' @param con DBI connection to DuckDB.
#' @param output One of `"csv"`, `"parquet"`, `"both"`.
#' @param dest Destination directory or `s3://` prefix. Defaults to `"CSV/"`,
#'   the path the package has always used.
#' @param normalize_empty Logical; collapse `''` to NULL in Parquet so it agrees
#'   with the CSV on read-back. See Details.
#' @param sort_key Column to sort by before writing Parquet, or NULL. Sorting
#'   makes row-group min/max statistics selective and shrinks the file: TY2023
#'   header went from 61.5 MB to 56.2 MB sorted on `ORG_EIN`. Every published
#'   table carries the KEYS columns, so `ORG_EIN` is always present.
#' @param compression Parquet codec. `"zstd"` gives 61.5 MB against snappy's
#'   109.7 MB on the TY2023 header table.
#' @param compression_level Integer zstd level.
#' @param row_group_size Rows per Parquet row group. 50,000 costs 2% in size
#'   over the 122,880 default but cuts the rows scanned for a point lookup from
#'   122,880 to 51,200.
#' @param temp_name Name of the DuckDB temporary table to materialise into.
#' @return Invisibly, a character vector of the paths written.
#' @export
write_table_output <- function( db_tbl, table_name, year, con,
                                output            = c( "csv", "parquet", "both" ),
                                dest              = "CSV/",
                                normalize_empty   = TRUE,
                                sort_key          = "ORG_EIN",
                                compression       = "zstd",
                                compression_level = 9L,
                                row_group_size    = 50000L,
                                temp_name         = "TEMP" ) {

  output <- match.arg( output )
  if ( ! grepl( "/$", dest ) ) dest <- paste0( dest, "/" )

  # Materialise once. Both COPY statements then read the same relation, which
  # is the point: the Parquet file is never a re-parse of the CSV.
  db_tbl %>% dplyr::compute( temp_name, temporary = TRUE, overwrite = TRUE )

  written <- character( 0 )
  stem    <- paste0( dest, table_name, "-", year )

  if ( output %in% c( "csv", "both" ) ) {
    fpath <- paste0( stem, ".CSV" )
    DBI::dbExecute( con, paste0(
      "COPY ", temp_name, " TO '", fpath, "' WITH ( HEADER, DELIMITER ',' );" ) )
    written <- c( written, fpath )
  }

  if ( output %in% c( "parquet", "both" ) ) {
    fpath <- paste0( stem, ".parquet" )

    schema <- DBI::dbGetQuery( con, paste0( "DESCRIBE ", temp_name ) )
    flds   <- schema$column_name

    if ( normalize_empty ) {
      # NULLIF only where the column is genuinely text. A non-VARCHAR column
      # would be an upstream surprise; pass it through rather than fail.
      is_txt <- grepl( "VARCHAR|CHAR|TEXT|STRING", schema$column_type )
      sel <- ifelse(
        is_txt,
        paste0( "NULLIF(", dbq( flds ), ", '') AS ", dbq( flds ) ),
        dbq( flds ) )
      sel <- paste( sel, collapse = ", " )
    } else {
      sel <- "*"
    }

    order_by <- ""
    if ( ! is.null( sort_key ) && sort_key %in% flds ) {
      order_by <- paste0( " ORDER BY ", dbq( sort_key ) )
    } else if ( ! is.null( sort_key ) ) {
      warning( sprintf( "%s-%s: sort_key '%s' not found; writing unsorted.",
                        table_name, year, sort_key ), call. = FALSE )
    }

    SQL <- sprintf(
      "COPY ( SELECT %s FROM %s%s ) TO '%s' ( FORMAT parquet, COMPRESSION %s, COMPRESSION_LEVEL %d, ROW_GROUP_SIZE %d );",
      sel, temp_name, order_by, fpath,
      compression, as.integer( compression_level ), as.integer( row_group_size ) )
    DBI::dbExecute( con, SQL )
    written <- c( written, fpath )
  }

  return( invisible( written ) )
}


#' Quote a SQL identifier
#'
#' @param x Character vector of identifiers.
#' @return Character vector of double-quoted identifiers, embedded quotes doubled.
#' @keywords internal
dbq <- function( x ) {
  paste0( '"', gsub( '"', '""', x ), '"' )
}


#' Verify that two serialisations of a table hold identical data
#'
#' @description
#' Compares a CSV and a Parquet file cell for cell without assuming either has a
#' unique key. Both are read all-VARCHAR, every row is hashed, and the hashes are
#' aggregated in sorted order, so the digest is independent of row order and of
#' ties.
#'
#' @details
#' Ordering by `OBJECTID` is not sufficient for a whole-table digest. In
#' `F9-P07-T02-CONTRACTORS-2023` there are 299,205 rows but only 215,278
#' distinct `OBJECTID` values, so any `ORDER BY OBJECTID` aggregate is
#' non-deterministic among ties and reports a spurious mismatch. Hashing rows and
#' sorting the hashes removes the need for a key at all.
#'
#' `fold_empty = TRUE` compares the CSV as every reader actually sees it, which
#' is the behaviour `normalize_empty = TRUE` in [write_table_output()] targets.
#'
#' @param csv_path Path or URL to the CSV.
#' @param parquet_path Path or URL to the Parquet file.
#' @param con DBI connection to DuckDB.
#' @param fold_empty Logical; treat `''` and NULL as equal on both sides.
#' @return A one-row data frame: row counts, column counts, digests, and `ok`.
#' @export
verify_table_output <- function( csv_path, parquet_path, con, fold_empty = TRUE ) {

  csv_rel <- sprintf( "read_csv('%s', all_varchar = true, sample_size = -1)", csv_path )
  pq_rel  <- sprintf( "read_parquet('%s')", parquet_path )

  cols_csv <- DBI::dbGetQuery( con, sprintf( "DESCRIBE SELECT * FROM %s", csv_rel ) )$column_name
  cols_pq  <- DBI::dbGetQuery( con, sprintf( "DESCRIBE SELECT * FROM %s", pq_rel  ) )$column_name

  if ( ! identical( cols_csv, cols_pq ) ) {
    return( data.frame( ok = FALSE, n_csv = NA_real_, n_pq = NA_real_,
                        ncol_csv = length( cols_csv ), ncol_pq = length( cols_pq ),
                        digest_csv = NA_character_, digest_pq = NA_character_,
                        note = "column names or order differ",
                        stringsAsFactors = FALSE ) )
  }

  cell <- if ( fold_empty ) paste0( "nullif(", dbq( cols_csv ), ", '')" ) else dbq( cols_csv )
  expr <- paste( paste0( "coalesce(", cell, ", '<<NULL>>')" ), collapse = ", " )

  digest <- function( rel ) DBI::dbGetQuery( con, sprintf(
    "SELECT md5( string_agg( h, '' ORDER BY h ) ) AS d, count(*) AS n FROM ( SELECT md5( concat_ws( '<|>', %s ) ) AS h FROM %s )",
    expr, rel ) )

  a <- digest( csv_rel )
  b <- digest( pq_rel )

  data.frame( ok         = identical( a$d, b$d ) && identical( a$n, b$n ),
              n_csv      = a$n,
              n_pq       = b$n,
              ncol_csv   = length( cols_csv ),
              ncol_pq    = length( cols_pq ),
              digest_csv = a$d,
              digest_pq  = b$d,
              note       = "",
              stringsAsFactors = FALSE )
}
