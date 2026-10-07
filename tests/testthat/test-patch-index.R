test_that("get_object_id2() reads the ID from the file name on any host", {
  id <- "202520139349300105"
  urls <- c(
    paste0("https://gt990datalake-rawdata.s3.amazonaws.com/EfileData/XmlFiles/", id, "_public.xml"),
    paste0("https://nccs-efile.s3.us-east-1.amazonaws.com/xml/", id, "_public.xml"),
    paste0("https://nccs-efile.s3.us-east-1.amazonaws.com/xml2/2022_TEOS_XML_01A/", id, "_public.xml"),
    patch_url(id, "v2_3")
  )
  expect_equal(get_object_id2(urls), rep(paste0("OID-", id), 4))
  expect_equal(get_object_id(urls), rep(paste0("OID-", id), 4))
  expect_equal(patch_url(id, "v2_3"),
    "https://nccs-efile.s3.us-east-1.amazonaws.com/xml2/v2_3_patch/202520139349300105_public.xml")
})

test_that("match_batch_zips() maps a batch to every zip sharing its stem", {
  zips <- data.frame(
    zip = c("2026_TEOS_XML_05A", "2026_TEOS_XML_05B", "2026_TEOS_XML_06A", "2024_TEOS_XML_04A"),
    stringsAsFactors = FALSE)
  m <- match_batch_zips(c("2026_TEOS_XML_05A", "2024_TEOS_XML_04a", NA), zips)
  expect_setequal(m$zip, c("2026_TEOS_XML_05A", "2026_TEOS_XML_05B", "2024_TEOS_XML_04A"))
})

test_that("diff_irs_gt() returns IRS rows missing from the GTDC index", {
  irs <- data.table::data.table(OBJECT_ID = c("1", "2", "3"), RETURN_TYPE = "990",
                                XML_BATCH_ID = c("A", "A", "B"))
  gt_id  <- data.frame(ObjectId = c(1, 3))
  gt_url <- data.frame(URL = "https://gt990datalake-rawdata.s3.amazonaws.com/EfileData/XmlFiles/3_public.xml")
  out <- suppressMessages(utils::capture.output(m1 <- diff_irs_gt(irs, gt_id)))
  expect_equal(m1$OBJECT_ID, "2")
  out <- suppressMessages(utils::capture.output(m2 <- diff_irs_gt(irs, gt_url)))
  expect_equal(m2$OBJECT_ID, c("1", "2"))
})

test_that("combine_index() keeps one row per filing and prefers GTDC", {
  gt <- data.frame(ObjectId = c("1", "2"), URL = c("gt/1", "gt/2"), TaxYear = 2024,
                   FormType = "990", Extra = "x")
  patch <- data.frame(ObjectId = c("2", "3"), URL = c("p/2", "p/3"), TaxYear = "2024",
                      FormType = "990PF")
  out <- suppressMessages(combine_index(gt, patch))
  expect_equal(out$ObjectId, c("1", "2", "3"))
  expect_equal(out$URL, c("gt/1", "gt/2", "p/3"))
  expect_equal(out$SOURCE, c("GTDC", "GTDC", "PATCH"))
  expect_type(out$TaxYear, "character")
})

test_that("read_return_headers() reads TaxYr, falling back to the period start", {
  dir <- tempfile("hdr"); dir.create(dir); on.exit(unlink(dir, recursive = TRUE))
  hdr <- function(extra) paste0(
    '<?xml version="1.0" encoding="utf-8"?>',
    '<Return xmlns="http://www.irs.gov/efile" returnVersion="2024v5.0"><ReturnHeader>',
    '<ReturnTs>2025-09-26T11:54:51-05:00</ReturnTs><TaxPeriodEndDt>2024-06-30</TaxPeriodEndDt>',
    '<ReturnTypeCd>990EZ</ReturnTypeCd><TaxPeriodBeginDt>2023-07-01</TaxPeriodBeginDt>',
    extra, '</ReturnHeader></Return>')
  writeLines(hdr("<TaxYr>2023</TaxYr>"), file.path(dir, "111_public.xml"))
  writeLines(hdr(""), file.path(dir, "222_public.xml"))
  h <- read_return_headers(file.path(dir, c("111_public.xml", "222_public.xml")))
  expect_equal(h$OBJECT_ID, c("111", "222"))
  expect_equal(h$TaxYear, c("2023", "2023"))
  expect_equal(h$FormType, c("990EZ", "990EZ"))
  expect_equal(h$ReturnVersion, c("2024v5.0", "2024v5.0"))
})

test_that("fetch_irs_xml() takes each batch from its own zips and resumes from its manifest", {
  root <- tempfile("fetch"); dir.create(root); on.exit(unlink(root, recursive = TRUE))
  src <- file.path(root, "src", "2026_TEOS_XML_05B"); dir.create(src, recursive = TRUE)
  for (id in c("111", "222", "333")) writeLines("<Return/>", file.path(src, paste0(id, "_public.xml")))
  zdir <- file.path(root, "zips"); dir.create(zdir)
  zip::zip(file.path(zdir, "2026_TEOS_XML_05B.zip"), files = "2026_TEOS_XML_05B",
           root = file.path(root, "src"))
  zips <- data.frame(year = 2026, zip = "2026_TEOS_XML_05B", url = "unused", stringsAsFactors = FALSE)
  # 333 sits in the zip but belongs to another batch, so it must not be taken.
  miss <- data.table::data.table(OBJECT_ID = c("111", "222", "333"),
                                 XML_BATCH_ID = c("2026_TEOS_XML_05A", "2026_TEOS_XML_05A", "2026_TEOS_XML_06A"))
  dest <- file.path(root, "dest")
  got1 <- suppressMessages(fetch_irs_xml(miss, dest, zips = zips, zip_dir = zdir, keep_zips = TRUE))
  expect_setequal(got1$OBJECT_ID, c("111", "222"))
  expect_equal(unique(got1$ZIP_FILE), "2026_TEOS_XML_05B")
  expect_false(file.exists(file.path(dest, "333_public.xml")))
  # A restart extracts nothing new but still reports the earlier files.
  got2 <- suppressMessages(fetch_irs_xml(miss, dest, zips = zips, zip_dir = zdir, keep_zips = TRUE))
  expect_setequal(got2$OBJECT_ID, c("111", "222"))
  expect_equal(unique(got2$ZIP_FILE), "2026_TEOS_XML_05B")
})
