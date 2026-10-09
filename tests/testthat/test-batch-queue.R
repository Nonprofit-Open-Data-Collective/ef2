# EF2-20: batches were split into fixed per-worker lists, so one slow batch
# stranded the rest of its worker's list while the other workers sat idle.

make_queue <- function(n, slow = character()) {
  dir <- tempfile("queue"); dir.create(dir)
  b <- stats::setNames(as.list(sprintf("file%02d", seq_len(n))), sprintf("G%02d{1}", seq_len(n)))
  b[slow] <- "slow"
  write_batches(b, dir)
  list(dir = dir, names = names(b))
}

batch_files <- function(dir) list.files(file.path(dir, "batches"), pattern = "\\.R$")
claims <- function(dir) basename(list.dirs(file.path(dir, "claimed"), recursive = FALSE))

test_that("a slow batch does not strand other batches; each batch runs once", {
  skip_on_cran()

  q <- make_queue(12, slow = "G01{1}")
  on.exit(unlink(q$dir, recursive = TRUE), add = TRUE)

  # Run the queue in real worker sessions, as build_database() does. Rehome the
  # function so future ships its code instead of loading the installed ef2,
  # which may predate it.
  rbq <- run_batch_queue
  environment(rbq) <- globalenv()
  process <- function(batch) Sys.sleep(if (identical(batch, "slow")) 6 else 0.2)
  year_path <- q$dir
  batchnames <- q$names

  old <- future::plan(future::multisession, workers = 3)
  on.exit(future::plan(old), add = TRUE)
  done <- furrr::future_map(1:3, ~ rbq(batchnames, year_path, process),
                            .options = furrr::furrr_options(seed = TRUE))

  all_done <- unlist(done)
  expect_setequal(all_done, q$names)
  expect_false(anyDuplicated(all_done) > 0)
  expect_length(batch_files(q$dir), 0)
  expect_length(claims(q$dir), 0)

  # A fixed split would give the slow batch's worker 4 of the 12 batches
  # (G01, G04, G07, G10), all finishing after the 6 s batch. With a shared
  # queue the other workers take the rest while it is busy.
  slow_worker <- which(vapply(done, function(d) "G01{1}" %in% d, logical(1)))
  expect_length(slow_worker, 1)
  expect_lt(length(done[[slow_worker]]), 4)
  expect_gt(sum(lengths(done) > 0), 1)
})

test_that("a failed batch is left for the next run, and only this run's batches are claimed", {
  q <- make_queue(4)
  on.exit(unlink(q$dir, recursive = TRUE), add = TRUE)

  process <- function(batch) if (batch == "file02") stop("bad filing")
  # G04 is not in this run's list, as for a leftover file from another run
  done <- run_batch_queue(q$names[1:3], q$dir, process)

  expect_identical(done, q$names[c(1, 3)])
  expect_setequal(batch_files(q$dir), c("G02{1}.R", "G04{1}.R"))
  expect_identical(claims(q$dir), "G02{1}")       # not retried in this run

  expect_equal(release_claimed_batches(q$dir), 1L)
  expect_length(claims(q$dir), 0)
  expect_setequal(names(gather_batches(q$dir)), c("G02{1}", "G04{1}"))
})

test_that("a batch another worker has claimed is skipped", {
  q <- make_queue(2)
  on.exit(unlink(q$dir, recursive = TRUE), add = TRUE)
  dir.create(file.path(q$dir, "claimed", "G01{1}"), recursive = TRUE)

  seen <- character()
  done <- run_batch_queue(q$names, q$dir, function(batch) seen <<- c(seen, batch))
  expect_identical(done, "G02{1}")
  expect_identical(seen, "file02")
  expect_identical(batch_files(q$dir), "G01{1}.R")
})
