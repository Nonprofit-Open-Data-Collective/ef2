# ---------------------------------------------------------------------------
# dev/update-chunked.R
#
# Resumable, chunked update for very large TaxYears (e.g. 2024, ~300k missing).
#
# Why: a single build of hundreds of thousands of filings is a multi-day,
# all-or-nothing job. This splits the missing URLs into fixed-size chunks, each
# built to its own temporary DuckDB with a done-marker, so the run is:
#   * recoverable  - re-running skips chunks already built/appended
#   * observable   - progress advances one chunk at a time
#   * tunable      - `workers` raises fetch parallelism (network-bound work)
#
# Flow per year:
#   missing URLs -> split into chunks -> build_database() per chunk (temp DB)
#                -> download base once -> append_to_database() per chunk -> validate
#
# Usage (REAL run — long!):
#   source("dev/update-chunked.R")
#   update_year_chunked(2024, chunk_size = 30000, workers = 10)
#
# Resume after interruption: just call it again with the SAME arguments.
# ---------------------------------------------------------------------------

library(ef2)

#' Chunked, resumable update for one TaxYear.
#'
#' @param year TaxYear to update.
#' @param index Optional index data frame; downloaded if NULL.
#' @param path Working directory for chunk temp DBs, the base copy, and markers.
#' @param chunk_size Missing URLs per chunk (default 30000).
#' @param workers Parallel fetch workers passed to build_database() (default 10).
#' @param group.size XML batch size (default 25).
#' @param version S3 version subfolder (default "efile_v2_1").
#' @param base_db Path to the base DuckDB to append into. NULL -> path/EFILE<year>.duckdb.
#' @param download_base If TRUE, download the S3 base to base_db (skips if present).
#' @param do_append If TRUE, append each built chunk into the base.
#' @param test_urls Optional explicit URL vector (bypasses index/S3 lookup) — for testing.
#' @return Invisibly, a list with the missing count, chunk temp DB paths, and base path.
update_year_chunked <- function(year,
                                index = NULL,
                                path = "efile-update-chunked",
                                chunk_size = 30000,
                                workers = 10,
                                group.size = 25,
                                version = "efile_v2_1",
                                base_db = NULL,
                                download_base = TRUE,
                                do_append = TRUE,
                                test_urls = NULL) {

  year <- as.character(year)
  dir.create(path, showWarnings = FALSE, recursive = TRUE)
  if (is.null(base_db)) base_db <- file.path(path, paste0("EFILE", year, ".duckdb"))

  ## --- 1. Resolve the missing-URL manifest (stable across resumes) ----------
  manifest <- file.path(path, paste0("missing_", year, ".txt"))
  if (file.exists(manifest)) {
    missing <- readLines(manifest)
    message("↩️  Reusing existing manifest: ", length(missing), " URLs")
  } else {
    if (!is.null(test_urls)) {
      missing <- test_urls
    } else {
      if (is.null(index)) {
        message("📥 Downloading current full index ...")
        index <- get_current_index_full()
      }
      index <- prep_index(years = year, index = index)
      missing <- find_missing_urls(year, index, version = version)
    }
    writeLines(missing, manifest)
    message("📝 Wrote manifest: ", length(missing), " URLs -> ", manifest)
  }

  if (length(missing) == 0) {
    message("✅ Nothing missing for ", year, " — up to date.")
    return(invisible(list(missing = 0L, chunks = character(0), base_db = base_db)))
  }

  ## --- 2. Split into chunks -------------------------------------------------
  chunks <- split(missing, ceiling(seq_along(missing) / chunk_size))
  n <- length(chunks)
  width <- nchar(n)
  message(sprintf("📦 %d URLs -> %d chunk(s) of up to %d (workers=%d)",
                  length(missing), n, chunk_size, workers))

  ## --- 3. Build each chunk (skip completed) ---------------------------------
  chunk_dbs <- character(n)
  for (i in seq_len(n)) {
    tag        <- sprintf("chunk%0*d", width, i)
    chunk_path <- file.path(path, tag)
    temp_db    <- file.path(chunk_path, year, paste0("EFILE", year, "_UPDATE.duckdb"))
    done       <- file.path(chunk_path, "BUILT")
    chunk_dbs[i] <- temp_db
    expected   <- length(chunks[[i]])

    if (file.exists(done) && file.exists(temp_db)) {
      message(sprintf("✔️  [%d/%d] %s already built — skipping", i, n, tag))
      next
    }

    message(sprintf("🔨 [%d/%d] Building %s (%d filings) ...", i, n, tag, expected))
    t0 <- Sys.time()
    build_database(year = year, urls = chunks[[i]], group.size = group.size,
                   path = chunk_path, is_update = TRUE, workers = workers)

    con <- DBI::dbConnect(duckdb::duckdb(), temp_db, read_only = TRUE)
    got <- DBI::dbGetQuery(con, "SELECT COUNT(DISTINCT URL) n FROM KEYS;")$n
    DBI::dbDisconnect(con, shutdown = TRUE)
    writeLines(as.character(got), done)
    message(sprintf("   %s built: %d/%d filings in %.1f min", tag, got, expected,
                    as.numeric(Sys.time() - t0, units = "mins")))
  }

  ## --- 4. Download base once ------------------------------------------------
  if (do_append && download_base) {
    download_s3_database(year, version = version, dest = base_db, overwrite = FALSE)
  }

  ## --- 5. Append each chunk into the base (idempotent via marker) -----------
  if (do_append) {
    stopifnot(file.exists(base_db))
    for (i in seq_len(n)) {
      tag        <- sprintf("chunk%0*d", width, i)
      appended   <- file.path(path, tag, "APPENDED")
      if (file.exists(appended)) {
        message(sprintf("✔️  [%d/%d] %s already appended — skipping", i, n, tag))
        next
      }
      message(sprintf("➕ [%d/%d] Appending %s ...", i, n, tag))
      append_to_database(base_db, chunk_dbs[i])
      writeLines(format(Sys.time()), appended)
    }
  }

  ## --- 6. Validate ----------------------------------------------------------
  if (do_append) {
    con <- DBI::dbConnect(duckdb::duckdb(), base_db, read_only = TRUE)
    DBI::dbExecute(con, "CREATE TEMP TABLE _m(url VARCHAR);")
    DBI::dbAppendTable(con, "_m", data.frame(url = missing))
    present <- DBI::dbGetQuery(con,
      "SELECT COUNT(DISTINCT k.URL) n FROM KEYS k JOIN _m m ON k.URL=m.url;")$n
    total_keys <- DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM KEYS;")$n
    DBI::dbDisconnect(con, shutdown = TRUE)
    message(sprintf("\n📋 %s: %d of %d new URLs present in base | base KEYS = %d",
                    year, present, length(missing), total_keys))
    message("PASS: ", present == length(missing))
  }

  invisible(list(missing = length(missing), chunks = chunk_dbs, base_db = base_db))
}
