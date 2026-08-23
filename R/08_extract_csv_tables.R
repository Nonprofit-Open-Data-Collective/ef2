
#' Flatten a logical RDB table into wide format from FLATXML
#'
#' @param table_name Character table identifier in the concordance.
#' @param year Integer year.
#' @param con DBI connection to DuckDB.
#' @return A lazy tibble (dbplyr) that can be `collect()`ed.
#' @export
flatten_table <- function( table_name, year, con ) {
  fn <- paste0( "EFILE", year, ".FLATXML" )
  db <- dplyr::tbl( con, fn )
  wide_00 <- db %>%
    dplyr::filter( .data$TYPE == "terminal" ) %>% 
    dplyr::filter( .data$RDB_TABLE == table_name ) %>%
    dplyr::select( .data$OBJECTID, .data$VARIABLE_NAME, .data$VALUE ) %>%
    tidyr::pivot_wider(
      names_from = .data$VARIABLE_NAME, 
      values_from = .data$VALUE,
      values_fill = ""
    )
  return( wide_00 )
}

#' Add KEYS columns to a flattened table
#'
#' @param db_tbl Lazy tibble (or data frame).
#' @param table_name Character table id.
#' @param year Integer year.
#' @param cc_file Concordance crosswalk data frame.
#' @param con DBI connection.
#' @return A tibble with KEYS columns relocated first.
#' @export
add_keys <- function( db_tbl, table_name, year, cc_file, con ) {
  keys   <- dplyr::tbl( con, paste0( "EFILE", year, ".KEYS" ) )
  db_tbl <- dplyr::right_join( keys, db_tbl, by = "OBJECTID" )

  new.order <- cc_file %>%
    dplyr::filter( .data$rdb_table == table_name ) %>%
    dplyr::arrange( .data$location_code_family, .data$xpath ) %>%
    dplyr::pull( .data$variable_name ) %>%
    base::unique()

  new.order <- new.order[ new.order %in% colnames( db_tbl ) ]
  key.names <- colnames( keys )
  db_tbl <- db_tbl %>% dplyr::relocate( c( key.names, new.order ) )
  return( db_tbl )
}

#' Build a structured wide table and optionally export to CSV/S3
#'
#' @param table_name Character table id.
#' @param year Integer year.
#' @param con DBI connection.
#' @param cc_file Concordance crosswalk.
#' @param post_to_s3 Logical, if TRUE write CSV to S3 using DuckDB COPY.
#' @return Invisibly the lazy tibble.
#' @export
build_table <- function( table_name, year, con, cc_file, post_to_s3 = FALSE ) {

  wide_00 <- flatten_table( table_name = table_name, year = year, con = con )
  wide_00 <- add_keys( db_tbl = wide_00, table_name = table_name, year = year, cc_file = cc_file, con = con )

  if ( post_to_s3 ) {
    write_csv_to_s3( db_tbl = wide_00, table_name = table_name, year = year, con = con )
  } else {
    fpath <- paste0( "CSV/", table_name, "-", year, ".CSV" ) 
    wide_00 %>% dplyr::compute( "TEMP", temporary = TRUE, overwrite = TRUE )
    SQL <- paste0( "COPY TEMP TO '", fpath, "' WITH ( HEADER, DELIMITER ',' );" )
    DBI::dbExecute( con, SQL )
  }
  return( invisible( wide_00 ) )
}

#' Build an RDB table from multiple header variants
#'
#' @param table_name Character table id.
#' @param year Integer year.
#' @param TABLE.HEADERS Named list of header xpaths per table. Used only when
#'   `selection = "header"`; the default path ignores it.
#' @param selection Row-selection strategy. `"rdb_table"` (default) filters on
#'   the `RDB_TABLE` column assigned during flattening -- exact, and immune to
#'   the header-prefix collisions described in EF2-6. `"header"` reproduces the
#'   legacy unanchored regex, for diffing old against new output only.
#' @param con DBI connection.
#' @param cc_file Concordance crosswalk.
#' @param post_to_s3 Logical export flag.
#' @return Invisibly the lazy tibble.
#' @export
build_rdb_table <- function( table_name, year, TABLE.HEADERS, con, cc_file,
                             post_to_s3 = FALSE,
                             selection = c( "rdb_table", "header" ) ) {

  selection <- match.arg( selection )
  db <- dplyr::tbl( con, paste0( "EFILE", year, ".FLATXML" ) )

  if ( selection == "rdb_table" ) {
    # RDB_TABLE is assigned during flattening from the concordance, so every
    # xpath resolves to exactly one table and selection cannot collide.
    #
    # This replaces an unanchored grepl() over TABLE.HEADERS. Because IRS part
    # names are Roman-numeral based, headers were routinely substrings of one
    # another -- Form990ScheduleRPartI matches PartII, PartIII and PartIV -- so
    # a table silently absorbed other tables rows. Measured on SR-P01 terminal
    # cells: TY2012 7,477,128 by header regex against 156,696 by RDB_TABLE;
    # TY2024 identical either way. 31 collisions across 17 tables in total.
    # See dev/UPSTREAM-ISSUES.md EF2-6 and dev/PLAN-fix-build-rdb-table.md.
    sel <- db %>% dplyr::filter( .data$RDB_TABLE == table_name )
  } else {
    # LEGACY, retained only to reproduce pre-fix output for diffing.
    # The regex MUST be built outside the filter: dbplyr cannot translate
    # paste0(collapse=) to SQL, so an inline paste0 fails at execution.
    hd <- gsub( "//", "/", TABLE.HEADERS[[ table_name ]] )
    xpath_versions <- paste0( hd, collapse = "|" )
    sel <- db %>% dplyr::filter( grepl( xpath_versions, .data$XPATH2 ) )
  }

  wide_xx <- sel %>%
    dplyr::filter( .data$TYPE == "terminal" ) %>%
    dplyr::select( .data$OBJECTID, .data$TABLE_ID, .data$VARIABLE_NAME, .data$VALUE ) %>%
    tidyr::pivot_wider( 
      names_from = .data$VARIABLE_NAME, 
      values_from = .data$VALUE,
      values_fill = "" )  

  keys <- dplyr::tbl( con, paste0( "EFILE", year, ".KEYS" ) )
  key.names <- colnames( keys )
  wide_xx <- dplyr::right_join( keys, wide_xx, by = "OBJECTID" )

  new.order <- cc_file %>%
    dplyr::filter( .data$rdb_table == table_name ) %>%
    dplyr::arrange( .data$location_code_family, .data$xpath ) %>%
    dplyr::pull( .data$variable_name ) %>%
    unique()

  new.order <- new.order[ new.order %in% colnames( wide_xx ) ]

  # Under selection = "rdb_table" every surviving column must be a key, TABLE_ID
  # or a concordance variable. That was NOT true of the header regex: xpaths
  # absent from the concordance fell back to the raw XML element name and rode
  # in as stray columns -- AddressOfContractor is column 30 of the published
  # F9-P07-T02-CONTRACTORS-2012.CSV. Warn rather than stop; a surprise here is
  # worth surfacing but not worth aborting a multi-year rebuild over.
  stray <- setdiff( colnames( wide_xx ), c( key.names, "TABLE_ID", new.order ) )
  if ( length( stray ) ) {
    warning( sprintf( "%s-%s: %d column(s) not in the concordance: %s",
                      table_name, year, length( stray ),
                      paste( stray, collapse = ", " ) ), call. = FALSE )
  }

  wide_xx <- wide_xx %>% dplyr::relocate( c( key.names, "TABLE_ID", new.order ) )

  if ( post_to_s3 ) {
    write_csv_to_s3( db_tbl = wide_xx, table_name = table_name, year = year, con = con )
  } else {
    fpath <- paste0( "CSV/", table_name, "-", year, ".CSV" )
    wide_xx %>% dplyr::compute( "TEMP", temporary = TRUE, overwrite = TRUE )
    SQL <- paste0( "COPY TEMP TO '", fpath, "' WITH ( HEADER, DELIMITER ',' );" )
    DBI::dbExecute( con, SQL )
  }
  return( invisible( wide_xx ) )
}




#' Extract All IRS 990 Tables from DuckDB Databases
#'
#' @description
#' Iterates over a set of DuckDB database files, one per tax year, and extracts
#' all tables defined in the IRS 990 efile schema. The function builds both
#' header tables T00 and data tables T01 to T99 for each year, saving
#' them into the database as flat relational tables.
#'
#' @details
#' The working directory (`wd`) should contain subdirectories named for each tax year,
#' and each of those subdirectories must include a DuckDB file such as
#' "EFILE2024.duckdb". The function calls helper functions like
#' `build_table()` and `build_rdb_table()` to populate these databases.
#'
#' @param wd Character. Base working directory containing yearly subfolders with
#'   DuckDB databases.
#' @param years Integer vector. Tax years to process (e.g., 2009:2024).
#' @param table_names Character vector of IRS 990 table names (defaults to
#'   [get_table_names()] if not supplied).
#' @param ccf Data frame. Concordance crosswalk used for variable alignment.
#' @param table_headers Data frame. Output of `get_table_headers()`, providing
#'   schema details for relational table construction.
#'
#' @return Invisibly returns `NULL`. Side effects: writes CSV tables for each year.
#'
#' @examples
#' \dontrun{
#' extract_csv_tables(
#'   wd = "C:/Users/jdlec/DATA/DUCKDB_2025",
#'   years = 2009:2024
#' )
#' }
#'
#' @export
extract_csv_tables <- function(wd,
                               years,
                               table_names = NULL,
                               ccf = NULL,
                               table_headers = NULL) {

  # ---- Input validation ----
  dir.create(file.path(wd,"CSV"),showWarnings=FALSE)
  if (!dir.exists(wd)) stop("Directory not found: ", wd)
  if (missing(years) || length(years) == 0) stop("Please supply one or more years.")
  if (is.null(table_names)) {
    table_names <- get_table_names()
    message("Using default table names from get_table_names()")
  }
  if (is.null(ccf)) { 
    ccf <- get_concordance()
    message("Using get_concordance() to generate ccf.") 
  }
  if (is.null(table_headers)) {
    table_headers <- get_table_headers()
    message("Using default table headers from get_table_headers()")
  }

  # ---- Split tables by type ----
  t00 <- grep("-T00-", table_names, value = TRUE)
  t01 <- grep("-T[0-9][1-9]-", table_names, value = TRUE)

  # ---- Main loop ----
  for (year in years) {
    db_file <- file.path(wd, year, paste0("EFILE", year, ".duckdb"))

    if (!file.exists(db_file)) {
      warning("Database not found for year ", year, ": ", db_file)
      next
    }

    message("Processing tax year ", year, " ...")

    con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_file)

    # Build header tables
    message("  Building header tables (T00)")
    purrr::walk(t00, build_table, year, con, ccf)

    # Build relational data tables
    message("  Building data tables")
    purrr::walk(t01, build_rdb_table, year, table_headers, con, ccf)

    DBI::dbDisconnect(con)
    gc()

    message("Completed: ", year)
  }

  message("Process complete for ", length(years), " years.")
  
  csv_files <- list.files(file.path(wd,"CSV"))
  invisible(csv_files)
}
