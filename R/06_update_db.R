
#' Identify missing URLs in a given tax year
#'
#' Compares the URLs stored in a DuckDB KEYS table (remote S3 database)
#' against URLs listed in an index data frame, identifying which filings
#' are missing from the database.
#'
#' @param year Integer tax year.
#' @param index Data frame with columns TaxYear and URL.
#' @param version S3 version subfolder under duckdb/ (default "efile_v2_1").
#'   Set to NULL or "" to target the unversioned duckdb/ path.
#' @return Character vector of missing URLs.
#' @export
find_missing_urls <- function(year, index, version = "efile_v2_1") {
  base::message("\U0001F50E Checking for missing URLs in TaxYear ", year)

  year <- as.character(year)
  version_seg <- if (base::is.null(version) || version == "") "" else base::paste0(version, "/")
  remote_db_url <- base::sprintf(
    "https://nccs-efile.s3.us-east-1.amazonaws.com/duckdb/%sEFILE%s.duckdb",
    version_seg, year
  )

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  DBI::dbExecute(con, "INSTALL httpfs;")
  DBI::dbExecute(con, "LOAD httpfs;")
  DBI::dbExecute(con, "SET s3_region='us-east-1';")
  DBI::dbExecute(con, base::sprintf("ATTACH '%s' AS src (READ_ONLY);", remote_db_url))

  urls_db <- 
    DBI::dbGetQuery(con, "SELECT DISTINCT url FROM src.KEYS;") |>
    dplyr::pull(.data$URL)

  DBI::dbDisconnect(con, shutdown = TRUE)

  urls_index <- index |>
    dplyr::filter(.data$TaxYear == year) |>
    dplyr::pull(.data$URL) |>
    base::unique()

  missing_urls <- base::setdiff(urls_index, urls_db)
  base::message(base::length(missing_urls), " missing URLs detected.")
  return(missing_urls)
}



#' Update the DuckDB database for a given tax year
#'
#' @param year Integer tax year.
#' @param index Data frame with TaxYear and URL columns.
#' @param path Directory for the temporary and merged database files.
#' @param version S3 version subfolder under duckdb/ (default "efile_v2_1").
#' @return Invisibly path to merged database or NULL.
#' @export
update_db <- function(year, index, path=".", version = "efile_v2_1") {
  base::message("\U0001F680 Updating database for TaxYear ", year)

  missing_urls <- find_missing_urls(year, index, version = version)

  if (base::length(missing_urls) == 0) {
    base::message("No missing files found. Database is up to date.")
    return(base::invisible(NULL))
  }

  base::message("Building temporary database with ", base::length(missing_urls), " missing files\n")
  
  temp_db_path <- build_database( year=year, urls=missing_urls, path=path, is_update=TRUE )  

  year_path <- file.path(path, year)
  dir.create(year_path, showWarnings = FALSE, recursive = TRUE)

  output_path <- paste0( path, "/EFILE", year, ".duckdb" )
  merge_databases( year, missing_urls, temp_db_path, output_path, version = version )

  base::message("\U0001F3AF Update complete for TaxYear ", year)
  base::message("The updated DB is located at ", output_path)
  base::invisible(output_path)
}



#' Merge DuckDB databases with schema alignment and timestamped logfile
#'
#' @param year Integer tax year.
#' @param missing_urls Character vector (for logging).
#' @param temp_db_path Path to temporary DuckDB with new filings.
#' @param output_path Path for final merged DB.
#' @param version S3 version subfolder under duckdb/ (default "efile_v2_1").
#' @return Invisibly `output_path`.
#' @export
merge_databases <- function(year, missing_urls, temp_db_path, output_path, version = "efile_v2_1") {
  base::message("\U0001F527 Merging databases for year ", year)

  version_seg <- if (base::is.null(version) || version == "") "" else base::paste0(version, "/")
  remote_db_url <- base::sprintf(
    "https://nccs-efile.s3.us-east-1.amazonaws.com/duckdb/%sEFILE%d.duckdb",
    version_seg, year
  )
  log_path <- base::sprintf("merge_log_%d.txt", year)
  log_conn <- base::file(log_path, open = "a")

  start_time <- base::Sys.time()
  base::writeLines(base::sprintf(
    "\n=== Merge Log for TaxYear %d ===\nStart Time: %s\nMissing URLs: %d\n",
    year, base::format(start_time, "%Y-%m-%d %H:%M:%S"), base::length(missing_urls)
  ), log_conn)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = output_path)
  DBI::dbExecute(con, "INSTALL httpfs;")
  DBI::dbExecute(con, "LOAD httpfs;")
  DBI::dbExecute(con, "SET s3_region='us-east-1';")

  DBI::dbExecute(con, base::sprintf("ATTACH '%s' AS src (READ_ONLY);", remote_db_url))
  DBI::dbExecute(con, base::sprintf("ATTACH '%s' AS tmpdb;", temp_db_path))

  merge_tables <- base::c("KEYS", "FLATXML", "ATTRIBUTES")

  for (tbl in merge_tables) {
    tbl_start <- base::Sys.time()
    tbls_src  <- DBI::dbListTables(con, "src")
    tbls_tmp  <- DBI::dbListTables(con, "tmpdb")

    if (!(tbl %in% tbls_src)) {
      base::warning("Skipping ", tbl, " \u2014 not found in source DB.")
      next
    }

    if (!DBI::dbExistsTable(con, tbl)) {
      DBI::dbExecute(con, base::sprintf("CREATE TABLE main.%s AS SELECT * FROM src.%s;", tbl, tbl))
      base::message("Copied ", tbl, " from source.")
    }

    before_count <- DBI::dbGetQuery(con, base::sprintf("SELECT COUNT(*) AS n FROM main.%s;", tbl))$n

    if (tbl %in% tbls_tmp) {
      cols_src  <- DBI::dbGetQuery(con, base::sprintf("PRAGMA table_info(src.%s);", tbl))$name
      cols_tmp  <- DBI::dbGetQuery(con, base::sprintf("PRAGMA table_info(tmpdb.%s);", tbl))$name
      all_cols  <- base::union(cols_src, cols_tmp)

      select_tmp <- base::paste(
        "SELECT",
        base::paste(base::sapply(all_cols, function(c)
          if (c %in% cols_tmp) base::sprintf("\"%s\"", c)
          else base::sprintf("NULL AS \"%s\"", c)
        ), collapse = ", "),
        base::sprintf("FROM tmpdb.%s;", tbl)
      )

      DBI::dbExecute(con, "BEGIN TRANSACTION;")
      DBI::dbExecute(con, base::sprintf("INSERT INTO main.%s (%s) %s",
        tbl,
        base::paste(base::sprintf('"%s"', all_cols), collapse = ", "),
        select_tmp
      ))
      DBI::dbExecute(con, "COMMIT;")

      after_count <- DBI::dbGetQuery(con, base::sprintf("SELECT COUNT(*) AS n FROM main.%s;", tbl))$n
      base::message("Appended ", tbl, " from temporary DB (schema aligned).")
    } else {
      after_count <- before_count
    }

    tbl_end <- base::Sys.time()
    duration <- base::round(base::as.numeric(tbl_end - tbl_start, units = "secs"), 2)

    base::writeLines(base::sprintf(
      "%s | %s | %d \u2192 %d rows | Duration: %.2f sec",
      tbl,
      base::format(tbl_end, "%Y-%m-%d %H:%M:%S"),
      before_count,
      after_count,
      duration
    ), log_conn)
  }

  DBI::dbExecute(con, "DETACH tmpdb;")
  DBI::dbExecute(con, "DETACH src;")
  DBI::dbDisconnect(con, shutdown = TRUE)

  total_time <- base::round(base::as.numeric(base::Sys.time() - start_time, units = "secs"), 2)
  base::writeLines(base::sprintf("Total Duration: %.2f sec\nMerge complete.\n", total_time), log_conn)
  base::close(log_conn)

  base::message("\u2705 Merged DB written to: ", output_path)
  base::message("\U0001F4DC Logfile saved at: ", log_path)
  base::invisible(output_path)
}

