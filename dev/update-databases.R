# ---------------------------------------------------------------------------
# dev/update-databases.R
#
# Orchestrated, incremental update of the NCCS efile DuckDB archive.
#
# Workflow:
#   1. Download the current "all years" GivingTuesday (GT) 990 e-file index.
#   2. For each TaxYear, compare index URLs to the URLs already stored in the
#      archived DuckDB KEYS table on NCCS S3 (find_missing_urls()).
#   3. Batch the missing filings by year, flatten their XML, and write a
#      temporary DuckDB (build_database(..., is_update = TRUE)).
#   4. Merge the temporary DB into a fresh local copy of the archive
#      (merge_databases()), producing EFILE<year>.duckdb.
#
# Typical use:
#   source("dev/update-databases.R")
#
#   # 1) See what is missing, download nothing heavy, build nothing (safe):
#   idx <- get_current_index_full()
#   summarize_missing(idx, years = 2021:2023)
#
#   # 2) Do a real, bounded test run for one year (a handful of filings):
#   update_databases(years = 2023, index = idx, path = "efile-update",
#                    dry_run = FALSE, sample_n = 5)
#
#   # 3) Full update for selected years:
#   update_databases(years = 2020:2023, index = idx, path = "efile-update",
#                    dry_run = FALSE)
# ---------------------------------------------------------------------------

library(ef2)


#' Summarize how many filings are missing from the archive, per TaxYear.
#'
#' Cheap and read-only: it does NOT download or build anything. Attaches the
#' remote KEYS table for each year and diffs against the index.
#'
#' @param index Data frame with TaxYear and URL columns (e.g. from
#'   get_current_index_full()).
#' @param years Optional vector of years. Defaults to every year in `index`.
#' @param version S3 version subfolder under duckdb/ (default "efile_v2_1").
#' @return A data.frame: TaxYear, in_index, in_archive, missing.
summarize_missing <- function(index, years = NULL, version = "efile_v2_1") {
  index <- prep_index(years = years, index = index)
  if (is.null(years)) years <- sort(unique(as.character(index$TaxYear)))
  years <- as.character(years)

  rows <- lapply(years, function(y) {
    n_index <- sum(as.character(index$TaxYear) == y)
    miss <- tryCatch(
      find_missing_urls(y, index, version = version),
      error = function(e) {
        message("  ⚠️  year ", y, " failed: ", conditionMessage(e))
        NULL
      }
    )
    n_missing <- if (is.null(miss)) NA_integer_ else length(miss)
    data.frame(
      TaxYear    = y,
      in_index   = n_index,
      in_archive = if (is.na(n_missing)) NA_integer_ else n_index - n_missing,
      missing    = n_missing,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  print(knitr::kable(out))
  invisible(out)
}


#' Update the archived DuckDB database for one or more TaxYears.
#'
#' @param years Optional vector of TaxYears to update. Defaults to every year
#'   present in `index`.
#' @param index Data frame with TaxYear, FormType, URL. If NULL, the current
#'   full index is downloaded via get_current_index_full().
#' @param path Output directory for per-year working folders and the merged
#'   EFILE<year>.duckdb files (default "efile-update").
#' @param version S3 version subfolder under duckdb/ (default "efile_v2_1").
#' @param dry_run If TRUE (default), only report what WOULD be built; nothing is
#'   downloaded/flattened/merged. Set FALSE to actually update.
#' @param sample_n Optional cap on the number of missing URLs processed per year
#'   (useful for a quick, bounded test run). NULL = process all missing.
#' @param group.size XML batch size passed to build_database() (default 25).
#' @return Invisibly, a named list (per year) of status + output path.
update_databases <- function(years = NULL,
                             index = NULL,
                             path = "efile-update",
                             version = "efile_v2_1",
                             dry_run = TRUE,
                             sample_n = NULL,
                             group.size = 25) {

  if (is.null(index)) {
    message("\U0001F4E5 Downloading current full index ...")
    index <- get_current_index_full()
  }

  index <- prep_index(years = years, index = index)   # years + 990/990EZ + dedup URL
  if (is.null(years)) years <- sort(unique(as.character(index$TaxYear)))
  years <- as.character(years)

  dir.create(path, showWarnings = FALSE, recursive = TRUE)
  results <- list()

  for (y in years) {
    message("\n==================  TaxYear ", y, "  ==================")

    missing <- tryCatch(
      find_missing_urls(y, index, version = version),
      error = function(e) {
        message("❌ Could not read archive for ", y, ": ", conditionMessage(e))
        NULL
      }
    )

    if (is.null(missing)) {
      results[[y]] <- list(missing = NA_integer_, status = "archive-error", output = NA_character_)
      next
    }

    if (!is.null(sample_n) && length(missing) > sample_n) {
      message("\U0001F9EA Sampling ", sample_n, " of ", length(missing), " missing URLs (test mode).")
      missing <- utils::head(missing, sample_n)
    }

    results[[y]] <- list(missing = length(missing), status = "pending", output = NA_character_)

    if (length(missing) == 0) {
      message("✅ Up to date — nothing to do.")
      results[[y]]$status <- "up-to-date"
      next
    }

    if (dry_run) {
      message("\U0001F440 DRY RUN — ", length(missing), " filings would be added.")
      results[[y]]$status <- "dry-run"
      next
    }

    out <- tryCatch({
      temp_db <- build_database(
        year = y, urls = missing, group.size = group.size,
        path = path, is_update = TRUE
      )
      output_path <- file.path(path, paste0("EFILE", y, ".duckdb"))
      merge_databases(y, missing, temp_db, output_path, version = version)
      output_path
    }, error = function(e) {
      message("❌ ERROR updating year ", y, ": ", conditionMessage(e))
      NA_character_
    })

    results[[y]]$status <- if (is.na(out)) "error" else "updated"
    results[[y]]$output <- out
  }

  message("\n\U0001F4CB Summary:")
  summ <- do.call(rbind, lapply(names(results), function(y) {
    data.frame(TaxYear = y,
               missing = results[[y]]$missing,
               status  = results[[y]]$status,
               output  = results[[y]]$output,
               stringsAsFactors = FALSE)
  }))
  print(knitr::kable(summ))

  invisible(results)
}
