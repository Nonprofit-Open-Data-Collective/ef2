
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
#' @param source_db Optional path/URL of the base ("source") database to merge
#'   into. Defaults to `NULL`, in which case the S3-hosted archive for `year`
#'   (under `version`) is used. Pass a local `.duckdb` path to merge into an
#'   already-downloaded archive or for testing.
#' @return Invisibly `output_path`.
#' @export
merge_databases <- function(year, missing_urls, temp_db_path, output_path, version = "efile_v2_1", source_db = NULL) {
  # Coerce year to character so filename/URL/log builders never hit sprintf("%d")
  # with a character TaxYear (a common failure mode when years come from an index).
  year <- base::as.character(year)
  base::message("\U0001F527 Merging databases for year ", year)

  if (base::is.null(source_db)) {
    version_seg <- if (base::is.null(version) || version == "") "" else base::paste0(version, "/")
    remote_db_url <- base::paste0(
      "https://nccs-efile.s3.us-east-1.amazonaws.com/duckdb/",
      version_seg, "EFILE", year, ".duckdb"
    )
  } else {
    remote_db_url <- source_db
  }
  log_path <- base::paste0("merge_log_", year, ".txt")
  log_conn <- base::file(log_path, open = "a")

  start_time <- base::Sys.time()
  base::writeLines(base::sprintf(
    "\n=== Merge Log for TaxYear %s ===\nStart Time: %s\nMissing URLs: %d\n",
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



#' Download an S3-hosted DuckDB archive to a local file
#'
#' Performs a plain (sequential/multipart) file download of the archived
#' `EFILE<year>.duckdb` rather than streaming the whole database through
#' `httpfs` SQL. For large archives (tens of GB) this is dramatically faster
#' than a `CREATE TABLE AS SELECT *` copy, and produces a local file that new
#' filings can be appended to directly (see [append_to_database()]).
#'
#' Uses the AWS CLI (`aws s3 cp --no-sign-request`) when available for
#' multipart parallelism, otherwise falls back to [utils::download.file()].
#'
#' @param year Tax year (integer or character).
#' @param version S3 version subfolder under duckdb/ (default "efile_v2_1").
#'   Set NULL or "" for the unversioned path.
#' @param dest Destination path. Defaults to `EFILE<year>.duckdb` in the
#'   working directory.
#' @param overwrite Logical; if FALSE (default) and `dest` already exists, the
#'   download is skipped.
#' @return Invisibly, the local destination path.
#' @export
download_s3_database <- function(year, version = "efile_v2_1", dest = NULL, overwrite = FALSE) {
  year <- base::as.character(year)
  version_seg <- if (base::is.null(version) || version == "") "" else base::paste0(version, "/")
  if (base::is.null(dest)) dest <- base::paste0("EFILE", year, ".duckdb")

  if (base::file.exists(dest) && !overwrite) {
    base::message("\u2139\ufe0f  File already exists, skipping download: ", dest)
    return(base::invisible(dest))
  }

  base::dir.create(base::dirname(dest), showWarnings = FALSE, recursive = TRUE)
  s3_uri  <- base::paste0("s3://nccs-efile/duckdb/", version_seg, "EFILE", year, ".duckdb")
  https   <- base::paste0("https://nccs-efile.s3.us-east-1.amazonaws.com/duckdb/",
                          version_seg, "EFILE", year, ".duckdb")

  aws <- base::Sys.which("aws")
  if (base::nzchar(aws)) {
    base::message("\U0001F4E5 Downloading via AWS CLI: ", s3_uri, " -> ", dest)
    status <- base::system2(aws, c("s3", "cp", base::shQuote(s3_uri), base::shQuote(dest),
                                   "--no-sign-request"))
    if (!base::identical(status, 0L)) {
      base::stop("aws s3 cp failed (exit ", status, ") for ", s3_uri)
    }
  } else {
    base::message("\U0001F4E5 Downloading via download.file(): ", https, " -> ", dest)
    old <- base::options(timeout = 36000L); base::on.exit(base::options(old), add = TRUE)
    utils::download.file(https, destfile = dest, mode = "wb", quiet = FALSE)
  }
  base::message("\u2705 Downloaded ", dest,
                " (", base::round(base::file.info(dest)$size / 1e9, 2), " GB)")
  base::invisible(dest)
}



#' Append a temporary DuckDB (new filings) into an existing local DuckDB
#'
#' Inserts the rows from a temporary "update" database (built by
#' [build_database()] with `is_update = TRUE`) into a base database in place,
#' aligning schemas. This is the local counterpart of [merge_databases()]:
#' pair it with [download_s3_database()] to update a large archive without
#' streaming the whole thing through `httpfs`.
#'
#' @param target_db Path to the base DuckDB to append into (modified in place).
#' @param temp_db_path Path to the temporary DuckDB with the new filings.
#' @param tables Character vector of tables to append
#'   (default `c("KEYS", "FLATXML", "ATTRIBUTES")`).
#' @return Invisibly, `target_db`.
#' @export
append_to_database <- function(target_db, temp_db_path,
                               tables = base::c("KEYS", "FLATXML", "ATTRIBUTES")) {
  if (!base::file.exists(target_db))    base::stop("target_db not found: ", target_db)
  if (!base::file.exists(temp_db_path)) base::stop("temp_db_path not found: ", temp_db_path)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = target_db)
  base::on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  DBI::dbExecute(con, base::sprintf("ATTACH '%s' AS tmpdb (READ_ONLY);", temp_db_path))
  tbls_tmp  <- DBI::dbListTables(con, "tmpdb")

  for (tbl in tables) {
    if (!(tbl %in% tbls_tmp)) {
      base::message("\u26a0\ufe0f  Skipping ", tbl, " \u2014 not found in temp DB.")
      next
    }

    if (!DBI::dbExistsTable(con, tbl)) {
      DBI::dbExecute(con, base::sprintf("CREATE TABLE main.%s AS SELECT * FROM tmpdb.%s;", tbl, tbl))
      n <- DBI::dbGetQuery(con, base::sprintf("SELECT COUNT(*) AS n FROM main.%s;", tbl))$n
      base::message("\U0001F195 Created ", tbl, " (", n, " rows) from temp DB.")
      next
    }

    cols_main <- DBI::dbGetQuery(con, base::sprintf("PRAGMA table_info(main.%s);", tbl))$name
    cols_tmp  <- DBI::dbGetQuery(con, base::sprintf("PRAGMA table_info(tmpdb.%s);", tbl))$name

    # Add any columns present in the temp DB but missing from the base.
    for (col in base::setdiff(cols_tmp, cols_main)) {
      DBI::dbExecute(con, base::sprintf('ALTER TABLE main.%s ADD COLUMN "%s" TEXT;', tbl, col))
    }
    all_cols <- base::union(cols_main, cols_tmp)

    select_tmp <- base::paste(
      "SELECT",
      base::paste(base::sapply(all_cols, function(c)
        if (c %in% cols_tmp) base::sprintf('"%s"', c)
        else base::sprintf('NULL AS "%s"', c)
      ), collapse = ", "),
      base::sprintf("FROM tmpdb.%s;", tbl)
    )

    before <- DBI::dbGetQuery(con, base::sprintf("SELECT COUNT(*) AS n FROM main.%s;", tbl))$n
    DBI::dbExecute(con, "BEGIN TRANSACTION;")
    DBI::dbExecute(con, base::sprintf("INSERT INTO main.%s (%s) %s",
      tbl,
      base::paste(base::sprintf('"%s"', all_cols), collapse = ", "),
      select_tmp
    ))
    DBI::dbExecute(con, "COMMIT;")
    after <- DBI::dbGetQuery(con, base::sprintf("SELECT COUNT(*) AS n FROM main.%s;", tbl))$n
    base::message(base::sprintf("\u2705 Appended %s: %d \u2192 %d rows (+%d)",
                                tbl, before, after, after - before))
  }

  DBI::dbExecute(con, "DETACH tmpdb;")
  base::invisible(target_db)
}

