#' Generate an XPATH Summary Report from a DuckDB Database
#'
#' @description
#' Connects to a DuckDB database containing IRS e-file XML tables and produces
#' a summary report of XPATH usage across filings. The report includes:
#' - One row per unique `XPATH2` value from the `FLATXML` table
#' - A count of occurrences across all filings
#' - A concatenated list of unique XML schema versions from the `KEYS` table
#'
#' @details
#' The function performs an inner join between `FLATXML` and `KEYS` on
#' `OBJECTID` (after removing duplicate `(OBJECTID, VERSION)` pairs to avoid
#' Cartesian product inflation). It then aggregates results by `XPATH2`.
#'
#' The result is written to a CSV file in the specified `output_dir`
#' and returned (invisibly) as a data frame.
#'
#' @param year Integer or character. Tax year of the database (used to locate the file
#'   and label the output CSV).
#' @param base_path Character. Base directory containing year-specific subfolders
#'   with the DuckDB database files (e.g., `EFILE2024.duckdb`).
#' @param output_dir Character. Directory where the CSV report will be written.
#'   Defaults to `"xpath_reports"`.
#' @param shutdown Logical. Whether to shut down DuckDB completely after disconnecting.
#'   Defaults to `TRUE`.
#'
#' @return Invisibly returns a data frame with columns:
#'   \describe{
#'     \item{xpath}{Unique XPATH2 string}
#'     \item{count_occurrences}{Number of occurrences in `FLATXML`}
#'     \item{count_filings}{Number of distinct filings (`OBJECTID`) using the xpath}
#'     \item{schema_versions}{Comma-separated list of distinct schema versions}
#'   }
#'
#' @examples
#' \dontrun{
#' generate_xpath_report(
#'   year = 2024,
#'   base_path = "C:/Users/jdlec/DATA/DUCKDB_2025"
#' )
#' }
#'
#' @export
generate_xpath_report <- function(year,
                                  base_path,
                                  output_dir = "xpath_reports",
                                  shutdown = TRUE) {
  # Load required packages
  if (!requireNamespace("DBI", quietly = TRUE) ||
      !requireNamespace("duckdb", quietly = TRUE)) {
    stop("Packages 'DBI' and 'duckdb' are required.")
  }

  # Construct database path
  db_path <- file.path(base_path, year, paste0("EFILE", year, ".duckdb"))

  if (!file.exists(db_path)) {
    stop("Database not found at: ", db_path)
  }

  # Connect to database
  con <- DBI::dbConnect(duckdb::duckdb(), db_path, read_only = TRUE)

  # SQL query
  sql <- "
  WITH KEYS_CLEAN AS (
      SELECT DISTINCT OBJECTID, VERSION
      FROM KEYS
  ),
  JOINED AS (
      SELECT 
          F.XPATH2 AS xpath,
          F.OBJECTID,
          K.VERSION
      FROM FLATXML AS F
      INNER JOIN KEYS_CLEAN AS K
          ON F.OBJECTID = K.OBJECTID
  )
  SELECT 
      xpath,
      COUNT(*) AS count_occurrences,
      COUNT(DISTINCT OBJECTID) AS count_filings,
      STRING_AGG(DISTINCT VERSION, ', ' ORDER BY VERSION) AS schema_versions
  FROM JOINED
  GROUP BY xpath
  ORDER BY count_occurrences DESC, xpath;
  "

  # Execute and fetch results
  message("Running XPATH report for tax year ", year, "...")
  xpath_report <- DBI::dbGetQuery(con, sql)

  # Close the connection
  DBI::dbDisconnect(con, shutdown = shutdown)

  # Create output directory if needed (under base_path)
  outdir <- file.path(base_path, output_dir)
  if (!dir.exists(outdir)) dir.create(outdir, recursive = TRUE)

  # File path
  outfile <- file.path(outdir, paste0(year, "-XPATH-REPORT.csv"))

  # Write to CSV
  utils::write.csv(xpath_report, outfile, row.names = FALSE)
  message("XPATH report saved to: ", outfile)

  # Return dataframe invisibly
  invisible(xpath_report)
}


#' Combine and Process Multi-Year XPATH Reports
#'
#' @description
#' The `process_xpaths()` function automates the full workflow of generating,
#' combining, and summarizing XPATH usage reports across multiple DuckDB databases.
#' It can process multiple tax years, merge the resulting reports, summarize
#' schema versions, and add derived metadata such as first/last year and
#' current version indicators.
#'
#' @details
#' This function:
#' 1. Iterates over a range of tax years and calls `generate_xpath_report()` for each.
#' 2. Reads all CSV reports from the specified `xpath_reports` directory.
#' 3. Combines and aggregates XPATH occurrences across years.
#' 4. Cleans and consolidates schema version lists using `combine_lists()`.
#' 5. Extracts first and last schema years and merges results with a
#'    `concordance` table if provided.
#'
#' The final combined report is saved to `"xpath_reports/ALL-XPATHS.csv"`.
#'
#' @param years Numeric vector of tax years to process.
#' @param base_path Character. Base path containing yearly DuckDB folders and
#'   the `xpath_reports` directory.
#' @param concordance Optional data frame containing a variable `xpath` for merging.
#'   If not supplied, the merge step is skipped.
#' @param get_type Optional function that accepts an XPATH string and returns a type label.
#'   Used to classify paths into `"HEADER"` or `"DATA"`.
#'
#' @return Invisibly returns a data frame containing all combined and processed XPATHs.
#'
#' @examples
#' \dontrun{
#' process_xpaths(
#'   years = 2009:2024,
#'   base_path = "C:/Users/jdlec/DATA/DUCKDB_2025",
#'   concordance = concordance,
#'   get_type = get_type
#' )
#' }
#'
#' @export
process_xpaths <- function(years,
                           base_path,
                           concordance = NULL,
                           get_type = NULL) {

  xpath_dir <- file.path(base_path, "xpath_reports")
  if (!dir.exists(xpath_dir)) dir.create(xpath_dir, recursive = TRUE)

  message("?? Generating XPATH reports for years: ", paste(years, collapse = ", "))
  purrr::walk(years, generate_xpath_report, base_path = base_path)

  # Only the per-year reports; ALL-XPATHS.csv from a previous run would double count
  files <- list.files(xpath_dir, pattern = "^[0-9]{4}-XPATH-REPORT\\.csv$", full.names = TRUE)
  L <- purrr::map(files, read.csv)
  xp <- dplyr::bind_rows(L)

  message("?? Aggregating XPATHs across years...")
  df <- xp %>%
    dplyr::group_by(xpath) %>%
    dplyr::summarize(
      count_occurrences = sum(count_occurrences),
      count_filings = sum(count_filings),
      schema_versions = paste0(schema_versions, collapse = ", ")
    ) %>%
    dplyr::arrange(dplyr::desc(count_occurrences)) %>%
    dplyr::ungroup()

  df$schema_versions <- vapply(df$schema_versions, combine_lists, FUN.VALUE = character(1))
  df$first_year <- vapply(df$schema_versions, get_first_year, FUN.VALUE = character(1))
  df$last_year <- vapply(df$schema_versions, get_last_year, FUN.VALUE = character(1))
  df$latest_version <- df$last_year
  df$current_version <- df$last_year == max(df$last_year)

  # Merge with concordance if available
  if (!is.null(concordance)) {
    message("?? Merging with concordance table...")
    f2 <- merge(df, concordance, by = "xpath", all = TRUE)
  } else {
    f2 <- df
  }

  # Add path type if get_type() is provided
  if (!is.null(get_type) && is.function(get_type)) {
    message("??? Classifying path types...")
    # get_type() classifies relative to the whole set, so call it once on all xpaths
    type <- get_type(f2$xpath)
    f2$path_type <- ifelse(type == "parent", "HEADER", "DATA")
  }

  f2 <- dplyr::arrange(f2, xpath)

  outfile <- file.path(xpath_dir, "ALL-XPATHS.csv")
  utils::write.csv(f2, outfile, row.names = FALSE, na = "")
  message("? Combined report saved to: ", outfile)

  invisible(f2)
}


# ---- Helper functions ----

#' Combine comma separated lists
#'
#' @param x Character vector of comma-separated schema version strings.
#' @return A cleaned string with unique, sorted versions separated by `;;`.
#' @keywords internal
combine_lists <- function(x) {
  y <- strsplit(x, ",") |> unlist() |> trimws() |> unique() |> sort()
  paste0(y, collapse = ";;")
}

#' Extract first year from combined schema string
#'
#' @param x Combined schema version string (delimited by ';;')
#' @return Four-digit year from the first version entry
#' @keywords internal
get_first_year <- function(x) {
  y <- strsplit(x, ";;") |> unlist()
  z <- head(y, 1)
  substr(z, 1, 4)
}

#' Extract last year from combined schema string
#'
#' @param x Combined schema version string (delimited by ';;')
#' @return Four-digit year from the last version entry
#' @keywords internal
get_last_year <- function(x) {
  y <- strsplit(x, ";;") |> unlist()
  z <- tail(y, 1)
  substr(z, 1, 4)
}