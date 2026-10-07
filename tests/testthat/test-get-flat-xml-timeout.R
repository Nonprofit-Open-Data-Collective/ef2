test_that("get_flat_xml() gives up on a stalled download and records the URL (EF2-15)", {
  skip_on_cran()

  # A socket that listens but never accepts: the OS completes the connection,
  # nothing ever answers. This is the stall that held a TY2012 worker for
  # 45 minutes when get_flat_xml() had no timeout.
  srv <- NULL
  for (port in sample(40000:49999, 20)) {
    srv <- tryCatch(serverSocket(port), error = function(e) NULL)
    if (!is.null(srv)) break
  }
  skip_if(is.null(srv), "no free local port")
  on.exit(close(srv), add = TRUE)

  url <- sprintf("http://127.0.0.1:%d/000000000000000000_public.xml", port)
  t0 <- Sys.time()
  r <- utils::capture.output(
    res <- get_flat_xml(url, retries = 2, pause_min = 0, pause_max = 0, timeout = 1)
  )
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  expect_identical(names(res), "FAILED_URLS")
  expect_identical(res$FAILED_URLS$failed_urls, url)
  expect_lt(secs, 30)
})
