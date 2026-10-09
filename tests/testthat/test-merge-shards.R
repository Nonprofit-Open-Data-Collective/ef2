# EF2-14: a resumed build left earlier worker shards unmerged.

make_shard <- function(path, ids) {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbWriteTable(con, "KEYS", data.frame(OBJECTID = ids, RETURN_TYPE = "990PF"), append = TRUE)
  DBI::dbWriteTable(con, "FLATXML", data.frame(OBJECTID = rep(ids, each = 2), ORDER = rep(1:2, length(ids))), append = TRUE)
  DBI::dbWriteTable(con, "ATTRIBUTES", data.frame(OBJECTID = ids, attr_name = "returnVersion"), append = TRUE)
  invisible(path)
}

counts <- function(db) {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  q <- function(s) DBI::dbGetQuery(con, s)[[1]]
  c(keys = q("SELECT count(*) FROM KEYS"),
    distinct = q("SELECT count(DISTINCT OBJECTID) FROM KEYS"),
    flatxml = q("SELECT count(*) FROM FLATXML"),
    attributes = q("SELECT count(*) FROM ATTRIBUTES"))
}

test_that("merge_duckdbs(skip_existing = TRUE) never copies a filing twice", {
  dir <- tempfile("shards"); dir.create(dir); on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  a <- make_shard(file.path(dir, "worker_01_2099.duckdb"), c("OID-1", "OID-2"))
  b <- make_shard(file.path(dir, "worker_02_2099.duckdb"), "OID-3")
  c3 <- make_shard(file.path(dir, "worker_03_2099.duckdb"), c("OID-3", "OID-4"))  # partly merged
  main <- file.path(dir, "EFILE2099.duckdb")

  suppressMessages(merge_duckdbs(main, a, skip_existing = TRUE))
  expect_equal(counts(main), c(keys = 2, distinct = 2, flatxml = 4, attributes = 2))

  # the resumed run merges everything in the folder, including a again
  suppressMessages(merge_duckdbs(main, c(a, b, c3), skip_existing = TRUE))
  expect_equal(counts(main), c(keys = 4, distinct = 4, flatxml = 8, attributes = 4))

  # the default still appends everything (original behaviour)
  suppressMessages(merge_duckdbs(main, a))
  expect_equal(counts(main)[["keys"]], 6)
})

test_that("merge_duckdbs() skips an empty shard (EF2-20: a worker that claimed no batch)", {
  dir <- tempfile("shards"); dir.create(dir); on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  a <- make_shard(file.path(dir, "worker_01_2099.duckdb"), c("OID-1", "OID-2"))
  empty <- file.path(dir, "worker_02_2099.duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = empty); DBI::dbDisconnect(con, shutdown = TRUE)
  main <- file.path(dir, "EFILE2099.duckdb")

  suppressMessages(merge_duckdbs(main, c(a, empty), skip_existing = TRUE))
  expect_equal(counts(main), c(keys = 2, distinct = 2, flatxml = 4, attributes = 2))
})

test_that("collect_worker_dbs() adds every shard of the year, once", {
  dir <- tempfile("shards"); dir.create(dir); on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  for (f in c("worker_01_2099.duckdb", "worker_11_2099.duckdb", "worker_12_2099.duckdb",
              "worker_01_2098.duckdb", "worker_01.log", "EFILE2099.duckdb"))
    file.create(file.path(dir, f))
  this_run <- file.path(dir, "worker_01_2099.duckdb")
  got <- basename(collect_worker_dbs(dir, "2099", this_run))
  expect_identical(got, c("worker_01_2099.duckdb", "worker_11_2099.duckdb", "worker_12_2099.duckdb"))
})
