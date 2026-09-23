#!/usr/bin/env Rscript
# One stage of one year.
#
# On 2026-09-17 a single R session building all 112 TY2012 tables through
# extract_csv_tables() segfaulted after 61 tables. Re-running the identical
# build on 2026-09-21 completed fine in 2.19 min, and sampling showed memory
# peaking at 27.9 GB during the T00 phase then falling back to ~9.5 GB -- about
# 11 GB at the point the original run died. So the crash is NOT memory
# accumulation and is NOT reproducible; cause unknown, treat as intermittent.
#
# Hence two build stages: "buildall" runs the documented entry point in one
# process, and "build" rebuilds a batch at a time, resuming from whatever is
# already on disk. The driver tries buildall first and falls back to batches.
#
# Usage: Rscript stage.R <year> <backfill|buildall|build|move|verify> [batch_size]

args  <- commandArgs(trailingOnly = TRUE)
YEAR  <- as.integer(args[1])
STAGE <- args[2]
BATCH <- if (length(args) >= 3) as.integer(args[3]) else 15L
stopifnot(!is.na(YEAR), STAGE %in% c("backfill","buildall","build","move","verify"))

ROOT  <- Sys.getenv("EFILE_ROOT", "C:/Users/jlecy/Documents/EFILE_BUILD_SEPT_2026")
NEW   <- file.path(ROOT, "NEW_TABLES")
STAGD <- file.path(NEW, "CSV")
LOGD  <- file.path(ROOT, "logs")
LOG   <- file.path(LOGD, "BUILD_LOG.tsv")
DB    <- file.path(ROOT, YEAR, sprintf("EFILE%d.duckdb", YEAR))
dir.create(STAGD, showWarnings = FALSE, recursive = TRUE)
dir.create(LOGD,  showWarnings = FALSE, recursive = TRUE)

log_line <- function(stage, status, detail = "") {
  cat(sprintf("%s\t%d\t%s\t%s\t%s\n",
              format(Sys.time(), "%Y-%m-%d %H:%M:%S"), YEAR, stage, status, detail),
      file = LOG, append = TRUE)
  message(sprintf("[%s] %d %s %s %s", format(Sys.time(), "%H:%M:%S"),
                  YEAR, stage, status, detail))
}

PKG <- Sys.getenv("EF2_PKG", ".")
suppressMessages(devtools::load_all(PKG, quiet = TRUE))
suppressMessages({library(duckdb); library(DBI)})

open_db <- function(read_only = FALSE) {
  con <- dbConnect(duckdb(), dbdir = DB, read_only = read_only)
  # Bound memory and give DuckDB somewhere to spill rather than die.
  try(dbExecute(con, "SET memory_limit='64GB';"), silent = TRUE)
  try(dbExecute(con, "SET threads=4;"), silent = TRUE)
  try(dbExecute(con, sprintf("SET temp_directory='%s';",
                             file.path(ROOT, "duckdb_tmp"))), silent = TRUE)
  con
}

# Tables still needing output: both serialisations must exist.
pending_tables <- function() {
  tn   <- get_table_names()
  have <- list.files(STAGD)
  csv  <- sub(sprintf("-%d[.]CSV$", YEAR), "", grep("[.]CSV$", have, value = TRUE))
  pq   <- sub(sprintf("-%d[.]parquet$", YEAR), "", grep("[.]parquet$", have, value = TRUE))
  done <- intersect(csv, pq)
  tn[!(tn %in% done)]
}

# ---------------------------------------------------------------- backfill --
if (STAGE == "backfill") {
  tgt <- "/Return/ReturnData/IRS990EZ/CompensationOfHighestPaidEmpl/ExpenseAccount"
  con <- open_db(read_only = FALSE)
  n <- dbExecute(con, sprintf(
    "UPDATE EFILE%d.FLATXML
        SET RDB_TABLE     = 'F9-P07-T01-COMPENSATION-HCE-EZ',
            VARIABLE_NAME = 'F9_07_COMP_DTK_EXP_ACCT_HCE'
      WHERE TYPE='terminal' AND XPATH2='%s'
        AND (RDB_TABLE IS NULL OR RDB_TABLE='')", YEAR, tgt))
  dbDisconnect(con, shutdown = TRUE)
  log_line("backfill", "OK", sprintf("ExpenseAccount cells remapped=%d", n))
}

# ---------------------------------------------------------------- buildall --
# The documented entry point, one process, whole year. Preferred path: this is
# what CLAUDE.md tells people to run, so it is the thing worth exercising.
if (STAGE == "buildall") {
  warn_log <- file.path(LOGD, sprintf("warnings-%d.txt", YEAR))
  old_wd <- getwd(); setwd(NEW)   # dest is a relative "CSV/" inside the builders
  t0 <- Sys.time()
  res <- try(withCallingHandlers(
    extract_csv_tables(wd = ROOT, years = YEAR, output = "both"),
    warning = function(w) {
      cat(sprintf("%s\n", conditionMessage(w)), file = warn_log, append = TRUE)
      invokeRestart("muffleWarning")
    }), silent = TRUE)
  setwd(old_wd)

  left <- length(pending_tables())
  mins <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 2)
  if (inherits(res, "try-error")) {
    message("  extract_csv_tables() raised: ", conditionMessage(attr(res, "condition")))
  }
  cat(sprintf("PENDING=%d\n", left))
  if (left == 0) log_line("build", "OK",
    sprintf("via=extract_csv_tables files=%d mins=%s warnings=%d",
            length(list.files(STAGD)), mins,
            if (file.exists(warn_log)) length(readLines(warn_log, warn = FALSE)) else 0))
}

# ------------------------------------------------------------------- build --
# Fallback: same code path extract_csv_tables() uses -- same functions, same
# arguments, same t00/t01 split -- driven a batch at a time so an intermittent
# crash costs one batch instead of the whole year.
if (STAGE == "build") {
  pend <- pending_tables()
  if (!length(pend)) { cat("PENDING=0\n"); quit(status = 0) }

  todo <- utils::head(pend, BATCH)
  ccf  <- get_concordance()
  th   <- get_table_headers()
  warn_log <- file.path(LOGD, sprintf("warnings-%d.txt", YEAR))

  old_wd <- getwd(); setwd(NEW)   # dest is a relative "CSV/" inside the builders
  con <- open_db(read_only = FALSE)
  built <- 0
  for (tb in todo) {
    ok <- tryCatch({
      withCallingHandlers({
        if (grepl("-T00-", tb)) build_table(tb, YEAR, con, ccf, output = "both")
        else                    build_rdb_table(tb, YEAR, th, con, ccf, output = "both")
        TRUE
      }, warning = function(w) {
        cat(sprintf("%s: %s\n", tb, conditionMessage(w)), file = warn_log, append = TRUE)
        invokeRestart("muffleWarning")
      })
    }, error = function(e) {
      cat(sprintf("%s: ERROR %s\n", tb, conditionMessage(e)), file = warn_log, append = TRUE)
      FALSE
    })
    if (isTRUE(ok)) built <- built + 1
  }
  dbDisconnect(con, shutdown = TRUE)
  setwd(old_wd)

  left <- length(pending_tables())
  message(sprintf("  batch built %d of %d, %d still pending", built, length(todo), left))
  cat(sprintf("PENDING=%d\n", left))
  if (left == 0) log_line("build", "OK",
    sprintf("files=%d warnings=%d", length(list.files(STAGD)),
            if (file.exists(warn_log)) length(readLines(warn_log, warn = FALSE)) else 0))
}

# -------------------------------------------------------------------- move --
if (STAGE == "move") {
  f <- list.files(STAGD, full.names = TRUE)
  moved <- sum(vapply(f, function(p) file.rename(p, file.path(NEW, basename(p))), logical(1)))
  left <- list.files(STAGD)
  if (!length(left)) unlink(STAGD, recursive = TRUE)
  log_line("move", "OK", sprintf("moved=%d remaining=%d", moved, length(left)))
}

# ------------------------------------------------------------------ verify --
if (STAGE == "verify") {
  con  <- dbConnect(duckdb(), dbdir = ":memory:")
  try(dbExecute(con, "SET memory_limit='64GB';"), silent = TRUE)
  csvs <- sort(list.files(NEW, pattern = sprintf("-%d[.]CSV$", YEAR), full.names = TRUE))
  vlog <- file.path(LOGD, sprintf("verify-%d.tsv", YEAR))
  cat("table\tok\tn_csv\tn_pq\tncol_csv\tncol_pq\tnote\n", file = vlog)
  nok <- 0; nbad <- 0; bad <- character(0)
  for (p in csvs) {
    q  <- sub("[.]CSV$", ".parquet", p)
    tb <- sub(sprintf("-%d[.]CSV$", YEAR), "", basename(p))
    r <- if (!file.exists(q)) {
      data.frame(ok = FALSE, n_csv = NA, n_pq = NA, ncol_csv = NA, ncol_pq = NA,
                 note = "parquet missing")
    } else tryCatch(verify_table_output(p, q, con),
                    error = function(e) data.frame(ok = FALSE, n_csv = NA, n_pq = NA,
                      ncol_csv = NA, ncol_pq = NA, note = conditionMessage(e)))
    cat(sprintf("%s\t%s\t%s\t%s\t%s\t%s\t%s\n", tb, r$ok, r$n_csv, r$n_pq,
                r$ncol_csv, r$ncol_pq, r$note), file = vlog, append = TRUE)
    if (isTRUE(r$ok)) nok <- nok + 1 else { nbad <- nbad + 1; bad <- c(bad, tb) }
  }
  dbDisconnect(con, shutdown = TRUE)
  log_line("verify", if (nbad == 0) "OK" else "WARN",
           sprintf("match=%d mismatch=%d%s", nok, nbad,
                   if (nbad) paste0(" [", paste(utils::head(bad, 5), collapse = ","), "]") else ""))
  if (nbad == 0) log_line("year", "OK", "complete")
}
