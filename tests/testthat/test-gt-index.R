base <- "https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/"

test_that("find_current_index() takes the newest file from the bucket listing", {
  local_mocked_bindings(
    list_gt_indices = function(...) c(
      "Indices/990xmls/index_all_years_efiledata_xmls_created_on_2024-11-24.csv",
      "Indices/990xmls/index_all_years_efiledata_xmls_created_on_2024-12-23.csv",
      "Indices/990xmls/index_all_years_efiledata_xmls_created_on_2024-12-23.parquet",
      "Indices/990xmls/index_latest_only_efiledata_xmls_created_on_2025-01-05.csv"
    ),
    url_is_valid = function(...) stop("should not probe when the listing works")
  )
  expect_message(
    url <- find_current_index_full(100),
    "dated 2024-12-23"
  )
  expect_equal(url, paste0(base, "index_all_years_efiledata_xmls_created_on_2024-12-23.csv"))
  url_b <- suppressMessages(find_current_index_batch(100))
  expect_equal(url_b, paste0(base, "index_latest_only_efiledata_xmls_created_on_2025-01-05.csv"))
})

test_that("find_current_index() falls back to probing by date when listing fails", {
  hit <- paste0(base, "index_all_years_efiledata_xmls_created_on_", Sys.Date() - 3, ".csv")
  local_mocked_bindings(
    list_gt_indices = function(...) NULL,
    url_is_valid = function(url) identical(url, hit)
  )
  expect_message(url <- find_current_index_full(10), "probing the last 10 days")
  expect_equal(url, hit)

  local_mocked_bindings(url_is_valid = function(url) FALSE)
  expect_true(is.na(suppressMessages(find_current_index_full(5))))
})

test_that("list_gt_indices() lists the bucket anonymously", {
  skip_on_cran()
  skip_if_offline("gt990datalake-rawdata.s3.us-east-1.amazonaws.com")
  keys <- list_gt_indices()
  skip_if(is.null(keys), "GTDC bucket not listable from here")
  expect_true(any(!is.na(extract_filenames_full(keys))))
  expect_true(any(!is.na(extract_filenames_batch(keys))))
})
