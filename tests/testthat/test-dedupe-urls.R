# EF2-19: an index lists some returns twice; build each filing once.

test_that("dedupe_urls() keeps one URL per ObjectId, in order", {
  gt  <- "https://gt990datalake-rawdata.s3.amazonaws.com/EfileData/XmlFiles/"
  mir <- "https://nccs-efile.s3.us-east-1.amazonaws.com/xml/"
  urls <- c(paste0(gt, "202200069349200015_public.xml"),
            paste0(gt, "202210409349300021_public.xml"),
            paste0(gt, "202200069349200015_public.xml"),   # re-indexed listing, same URL
            paste0(mir, "202210409349300021_public.xml"),  # same return, other URL form
            NA, "")
  expect_message(out <- dedupe_urls(urls), "Dropped 2 repeated filing")
  expect_identical(out, urls[1:2])
  expect_silent(dedupe_urls(urls[1:2]))
})

test_that("check_unique_keys() stops when a filing is stored twice", {
  db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db), add = TRUE)
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db)
  DBI::dbWriteTable(con, "KEYS", data.frame(OBJECTID = c("OID-1", "OID-2")))
  DBI::dbDisconnect(con, shutdown = TRUE)
  expect_equal(check_unique_keys(db), 2)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db)
  DBI::dbWriteTable(con, "KEYS", data.frame(OBJECTID = "OID-2"), append = TRUE)
  DBI::dbDisconnect(con, shutdown = TRUE)
  expect_error(check_unique_keys(db), "3 rows for 2 filings")
})
