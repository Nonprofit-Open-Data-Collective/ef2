

#' Build a DuckDB database from batches of XML filings (parallel safe)
#'
#' Processes XML batches in parallel, with each worker writing to its own DuckDB
#' shard. When all workers complete, the shards are merged into a unified
#' database for the specified year.
#'
#' @param year Integer. Year label for the database.
#' @param urls Optional character vector of XML URLs to process. If NULL,
#'   resumes from existing batch files in the year's folder.
#' @param group.size Integer batch size (default = 25).
#' @param ccf Concordance crosswalk object (optional).
#' @param path Directory in which to store year subfolder and database files.
#' @param is_update Logical; if TRUE, this is an incremental update build rather
#'   than a full-year rebuild.
#'
#' @return Invisibly returns the path to the merged DuckDB database.
#'
#' @examples
#' \dontrun{
#' build_database(2021, urls = urls, group.size = 25, path = "data")
#' }
#' @export
build_database <- function(year, urls = NULL, group.size = 25,
                           ccf = NULL, path = ".", is_update=FALSE) {

  # --- Helper: portable in-memory detection ---
  is_in_memory_duckdb <- function(con) {
    info <- tryCatch(DBI::dbGetInfo(con), error = function(e) list(dbname = NA))
    isTRUE(identical(info$dbname, ":memory:"))
  }

  # --- Setup paths and batch structure ---
  # Coerce year to character so all filename builders below are safe with a
  # character TaxYear (avoids sprintf("%d", "2021") errors).
  year <- as.character(year)
  ccf <- prep_concordance(ccf)
  year_path <- normalizePath(file.path(path, year), mustWork = FALSE)
  dir.create(year_path, showWarnings = FALSE, recursive = TRUE)

  # --- Use existing or new batch files ---
  if (!is.null(urls)) {
    message("\U0001F4E6 Creating new batch files for ", year)
    batchfile <- split_urls(urls = urls, group.size = group.size, path = year_path)
  } else {
    message("\u21A9\uFE0F  Resuming existing batches for ", year)
    batchfile <- gather_batches(year_path)
  }
  n_batches <- length(batchfile)
  if (n_batches == 0) {
    message("\u2705 No batches to process for ", year)
    return(invisible(NULL))
  }

  # --- Parallel configuration ---
  max.cores <- min(4, floor(future::availableCores() / 2))
  on.exit(future::plan(future::sequential), add = TRUE)
  future::plan(future::multisession, workers = max.cores)

  # --- Partition batches across workers ---
  worker_assignments <- split(names(batchfile),
                              rep(1:max.cores, length.out = n_batches))

  message("\U0001F9EE Processing ", n_batches, " batches across ",
          max.cores, " workers for ", year, "...")

  # --- Logging helper (defined outside workers for serialization safety) ---
  make_logger <- function(worker_id, year_path) {
    log_file <- file.path(year_path, sprintf("worker_%02d.log", worker_id))
    force(log_file)
    function(...) {
      msg <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " | ",
                    paste(..., collapse = " "), "\n")
      cat(msg, file = log_file, append = TRUE)
      cat(msg)
    }
  }

  # --- Worker function ---
  worker_func <- function(worker_id, batchnames, year_path, ccf) {

    # Load package explicitly inside worker
    suppressMessages(library(ef2))

    log_msg <- make_logger(worker_id, year_path)
    log_msg("Starting worker", worker_id)

    worker_db <- normalizePath(
      file.path(year_path, sprintf("worker_%02d_%s.duckdb", worker_id, year)),
      mustWork = FALSE
    )
    log_msg("Connecting to DuckDB:", worker_db)

    # --- Create connection ---
    con <- tryCatch(
      DBI::dbConnect(duckdb::duckdb(), dbdir = worker_db),
      error = function(e) {
        log_msg("\u274C Connection error:", conditionMessage(e))
        return(NULL)
      }
    )

    if (is.null(con) || !DBI::dbIsValid(con)) {
      log_msg("\u274C Invalid connection; skipping worker", worker_id)
      return(worker_db)
    }

    if (is_in_memory_duckdb(con)) {
      stop("Worker ", worker_id, " is using an in-memory DuckDB; check file path or permissions.")
    }

    # --- Process each batch ---
    for (batchname in batchnames) {
      batch <- batchfile[[batchname]]
      if (is.null(batch)) next

      start_time <- Sys.time()
      log_msg("Processing batch", batchname, "with", length(batch), "files")

      tryCatch({
        batch_flatten(batch, con = con, ccf = ccf)
        remove_batch(batchname, path = year_path)
        elapsed <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 1)
        log_msg("\u2705 Completed batch", batchname, "in", elapsed, "sec")
      },
      error = function(e) {
        log_msg("\u2757 Error in batch", batchname, ":", conditionMessage(e))
      })
    }

    DBI::dbDisconnect(con, shutdown = TRUE)
    log_msg("Closed connection for worker", worker_id)
    return(worker_db)
  }

  # --- Launch workers ---
  worker_dbs <- furrr::future_map_chr(
    seq_along(worker_assignments),
    ~ worker_func(
        worker_id   = .x,
        batchnames  = worker_assignments[[.x]],
        year_path   = year_path,
        ccf         = ccf
      ),
    .options = furrr::furrr_options(seed = TRUE),
    .progress = FALSE
  )

  # --- Merge all worker databases ---
  future::plan(future::sequential)
  main_db <- file.path(year_path, paste0("EFILE", year, ".duckdb"))
  if(is_update){main_db <- file.path(year_path, paste0("EFILE", year, "_UPDATE.duckdb"))}
  message("\n\U0001FA84 Merging ", length(worker_dbs), " worker databases into ", main_db)
  merge_duckdbs(main_db, worker_dbs)

  message("\n\U0001F389 All batches processed and merged for ", year)
  invisible(main_db)
}



#' Resume a partial DuckDB build
#'
#' Resumes an interrupted build by gathering remaining batch files in the
#' year's \code{batches/} folder and calling \code{build_database()} to
#' process only those batches. Existing worker databases are reused and
#' appended to if present.
#'
#' @param year Integer. Data year (subdirectory name).
#' @param ccf Concordance crosswalk, prepared via \code{prep_concordance()}.
#' @param path Project directory containing the year subfolder.
#'
#' @return Invisibly returns the path to the merged DuckDB database.
#' @examples
#' \dontrun{
#' resume_build_database(2021, path = "data")
#' }
#' @export
resume_build_database <- function(year, ccf = NULL, path = ".") {
  year_path <- file.path(path, year)
  ccf  <- prep_concordance(ccf)
  batchfile <- gather_batches(year_path)
  n_batches <- length(batchfile)

  if (n_batches == 0) {
    message("\u2705 No remaining batches to process for ", year)
    return(invisible(NULL))
  }

  build_database(year = year, urls = NULL, ccf = ccf, path = path)
}


#' Merge multiple worker DuckDB databases into a main database
#'
#' This function combines tables (ATTRIBUTES, FLATXML, KEYS) from multiple
#' worker databases into a single main DuckDB database. It aligns schemas,
#' handles transactions, and logs merge details.
#'
#' @param main_db Path to the output DuckDB database (will be created if missing).
#' @param worker_dbs Character vector of worker database file paths.
#' @param overwrite Logical; if TRUE, deletes existing main database before merging.
#' @param cleanup Logical; if TRUE, deletes worker databases after merging.
#' @return Invisibly returns the path to the merged database.
#' @export
merge_duckdbs <- function(main_db, worker_dbs, overwrite = FALSE, cleanup = FALSE) {
  stopifnot(length(worker_dbs) > 0)

  message("\U0001F527 Merging ", length(worker_dbs), " worker databases...")

  if (overwrite && file.exists(main_db)) {
    message("\U0001F9F9 Removing existing main database: ", basename(main_db))
    unlink(main_db, force = TRUE)
  }

  log_path <- file.path(dirname(main_db), "merge_log.txt")
  log_conn <- file(log_path, open = "a")

  start_time <- Sys.time()
  writeLines(sprintf(
    "\n=== Merge Log for %s ===\nStart Time: %s\nWorker DBs: %d\n",
    basename(main_db),
    format(start_time, "%Y-%m-%d %H:%M:%S"),
    length(worker_dbs)
  ), log_conn)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = main_db)
  on.exit({
    DBI::dbDisconnect(con, shutdown = TRUE)
    close(log_conn)
  }, add = TRUE)

  merge_tables <- c("KEYS", "FLATXML", "ATTRIBUTES")

  for (dbs in worker_dbs) {
    if (!file.exists(dbs)) {
      warning("Skipping missing DB: ", dbs)
      next
    }

    alias <- paste0("src_", gsub("\\W", "_", basename(dbs)))
    message("\U0001F517 Attaching worker DB: ", basename(dbs))
    DBI::dbExecute(con, sprintf("ATTACH '%s' AS %s (READ_ONLY);", dbs, alias))

    tbls_src <- DBI::dbListTables(con, alias)

    for (tbl in merge_tables) {
      tbl_start <- Sys.time()

      if (!(tbl %in% tbls_src)) {
        message("\u26A0\uFE0F  Skipping ", tbl, " \u2014 not found in ", basename(dbs))
        next
      }

      # Create target table if not present
      if (!DBI::dbExistsTable(con, tbl)) {
        DBI::dbExecute(con, sprintf(
          "CREATE TABLE main.%s AS SELECT * FROM %s.%s LIMIT 0;", tbl, alias, tbl
        ))
        message("\U0001F195 Created table ", tbl)
      }

      # Schema alignment
      cols_src <- DBI::dbGetQuery(con, sprintf("PRAGMA table_info(%s.%s);", alias, tbl))$name
      cols_main <- DBI::dbGetQuery(con, sprintf("PRAGMA table_info(main.%s);", tbl))$name
      all_cols <- union(cols_src, cols_main)

      select_src <- paste(
        "SELECT",
        paste(sapply(all_cols, function(c)
          if (c %in% cols_src) sprintf('"%s"', c)
          else sprintf("NULL AS \"%s\"", c)
        ), collapse = ", "),
        sprintf("FROM %s.%s;", alias, tbl)
      )

      # Copy rows in a transaction
      before_count <- DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM main.%s;", tbl))$n
      DBI::dbExecute(con, "BEGIN TRANSACTION;")
      DBI::dbExecute(con, sprintf(
        "INSERT INTO main.%s (%s) %s",
        tbl,
        paste(sprintf('"%s"', all_cols), collapse = ", "),
        select_src
      ))
      DBI::dbExecute(con, "COMMIT;")
      after_count <- DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM main.%s;", tbl))$n

      duration <- round(as.numeric(Sys.time() - tbl_start, units = "secs"), 2)
      message(sprintf("\u2705 Appended %d rows to %s (%.2f sec)", after_count - before_count, tbl, duration))
      writeLines(sprintf(
        "%s | %s | %d \u2192 %d rows | Duration: %.2f sec | %s",
        tbl,
        format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        before_count,
        after_count,
        duration,
        basename(dbs)
      ), log_conn)
    }

    DBI::dbExecute(con, sprintf("DETACH %s;", alias))
  }

  if (cleanup) {
    message("\U0001F9FD Removing worker databases...")
    unlink(worker_dbs, force = TRUE)
  }

  total_time <- round(as.numeric(Sys.time() - start_time, units = "secs"), 2)
  writeLines(sprintf("Total Duration: %.2f sec\nMerge complete.\n", total_time), log_conn)
  message("\u2705 Merge complete: ", basename(main_db))
  message("\U0001F4DC Log saved to: ", log_path)

  invisible(main_db)
}


#' Validate a merged DuckDB database against its worker sources
#'
#' Compares table structures and row counts between a main merged DuckDB
#' and the worker databases it was built from.  Each table's row counts
#' from all workers are summed and compared with the main database total.
#'
#' @param main_db Path to the main DuckDB database (e.g. `"EFILE2021.duckdb"`).
#' @param worker_dbs Character vector of worker database file paths
#'   (e.g. all `worker_XX_YYYY.duckdb` files).
#' @return A tibble summarizing row counts for each table:
#'   \itemize{
#'     \item `table_name` - table name
#'     \item `main_rows` - number of rows in the merged database
#'     \item `worker_sum` - total rows across all workers
#'     \item `n_workers` - number of workers containing that table
#'     \item `match` - TRUE/FALSE indicating if totals match
#'   }
#' @examples
#' \dontrun{
#' validate_merge("EFILE2021.duckdb",
#'                list.files("2021", pattern = "worker_.*\\.duckdb$", full.names = TRUE))
#' }
#' @export
validate_merge <- function(main_db, worker_dbs) {
  stopifnot(file.exists(main_db))
  stopifnot(length(worker_dbs) > 0)

  message("\U0001F50D Validating merged database against ", length(worker_dbs), " workers...")

  # --- Helper: count rows in one DuckDB ---
  count_tables <- function(db_path) {
    con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = TRUE)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

    tbls <- DBI::dbListTables(con)
    if (length(tbls) == 0)
      return(data.frame(table_name = character(), n_rows = numeric(), stringsAsFactors = FALSE))

    res <- lapply(tbls, function(t) {
      n <- tryCatch(
        DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM \"%s\";", t))$n,
        error = function(e) NA_integer_
      )
      data.frame(table_name = t, n_rows = n, stringsAsFactors = FALSE)
    })
    do.call(rbind, res)
  }

  # --- Count rows in main and workers ---
  main_counts <- count_tables(main_db)
  main_counts$db <- "main"

  worker_counts <- lapply(worker_dbs, count_tables)
  for (i in seq_along(worker_counts))
    worker_counts[[i]]$db <- basename(worker_dbs[i])
  worker_counts <- dplyr::bind_rows(worker_counts)

  # --- Aggregate worker totals per table ---
  worker_summary <- worker_counts |>
    dplyr::group_by(table_name) |>
    dplyr::summarise(
      worker_sum = sum(n_rows, na.rm = TRUE),
      n_workers = dplyr::n_distinct(db),
      .groups = "drop"
    )

  # --- Combine with main counts ---
  comparison <- dplyr::full_join(main_counts, worker_summary, by = "table_name") |>
    dplyr::mutate(
      match = dplyr::if_else(is.na(main_rows <- n_rows), FALSE, main_rows == worker_sum)
    ) |>
    dplyr::select(table_name, main_rows = n_rows, worker_sum, n_workers, match) |>
    dplyr::arrange(dplyr::desc(main_rows))

  # --- Print summary nicely ---
  message("\n\U0001F4CA Row count comparison:")
  print(comparison, n = nrow(comparison))

  mismatches <- comparison |> dplyr::filter(!match | is.na(match))
  if (nrow(mismatches) == 0) {
    message("\n\u2705 All tables validated successfully! Totals match across main and workers.")
  } else {
    message("\n\u26A0\uFE0F  Mismatched row counts detected in: ",
            paste(mismatches$table_name, collapse = ", "))
  }

  invisible(comparison)
}


