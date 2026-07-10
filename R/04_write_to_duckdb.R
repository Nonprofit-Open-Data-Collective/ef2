
#' Ensure destination DuckDB table has all required columns
#'
#' Adds any missing columns (as TEXT) needed to append `new_data` into an
#' existing DuckDB table.
#'
#' @param new_data Data frame with new data to append.
#' @param table_name Character table name.
#' @param con DBI connection to DuckDB.
#' @export
check_for_columns <- function( new_data, table_name, con ){
  tbls <- DBI::dbListTables(con)
  if( ! table_name %in% tbls ) { return(invisible(NULL)) }

  existing_cols <- colnames(dplyr::tbl( con,  table_name ))
  new_cols <- colnames(new_data)
  missing_cols <- setdiff(new_cols, existing_cols)

  if (length(missing_cols) > 0) {
    for (col in missing_cols) {
      alter_query <- sprintf('ALTER TABLE %s ADD COLUMN "%s" TEXT', table_name, col) 
      DBI::dbExecute( con, alter_query )
    }
  }
}

#' Write flattened XML batch results to an existing DuckDB connection
#'
#' @param RESULTS List of parsed XML outputs from `get_flat_xml()`.
#' @param con Active DBI connection to DuckDB (persistent).
#' @return Invisibly TRUE on success.
#' @export
send_flat_xml_to_db <- function(RESULTS, con) {

  safe_write <- function(tbl_name, data_list) {
    df <- lapply(data_list, `[[`, tbl_name) |> dplyr::bind_rows()
    if (nrow(df) == 0) return(invisible(FALSE))
    df[] <- lapply(df, as.character)
    check_for_columns(df, table_name = tbl_name, con = con)
    DBI::dbWriteTable(con, tbl_name, df, append = TRUE)
    invisible(TRUE)
  }

  try(safe_write("FLATXML",    RESULTS), silent = TRUE)
  try(safe_write("ATTRIBUTES", RESULTS), silent = TRUE)
  try(safe_write("KEYS",       RESULTS), silent = TRUE)

  try({
    failed_urls <- lapply(RESULTS, `[[`, "FAILED_URLS") |> dplyr::bind_rows()
    if (nrow(failed_urls) > 0) {
      failed_urls[] <- lapply(failed_urls, as.character)
      DBI::dbWriteTable(con, "FAILED_URLS", failed_urls, append = TRUE)
    }
  }, silent = TRUE)

  cat("  \u2705 Data successfully written to DuckDB!\n")
  invisible(TRUE)
}
