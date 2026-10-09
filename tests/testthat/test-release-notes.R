make_release <- function(dir, tables) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  for (nm in names(tables)) {
    DBI::dbWriteTable(con, "t", tables[[nm]], overwrite = TRUE)
    DBI::dbExecute(con, sprintf("COPY t TO '%s' (FORMAT PARQUET)", file.path(dir, paste0(nm, ".parquet"))))
  }
}

test_that("condense_years() collapses runs into ranges", {
  expect_equal(condense_years(c(2013, 2009, 2010, 2011)), "2009-2011, 2013")
  expect_equal(condense_years(2020), "2020")
  expect_equal(condense_years(integer(0)), "")
})

test_that("compare_releases() reports tables, columns, rows, filings and labels", {
  root <- tempfile("rel"); on.exit(unlink(root, recursive = TRUE))
  hdr <- function(n, rt = "990") data.frame(OBJECTID = sprintf("OID-%018d", seq_len(n)), RETURN_TYPE = rt, A = "x")
  make_release(file.path(root, "old"), list(
    "F9-P00-T00-HEADER-2023" = hdr(3),
    "F9-P00-T00-HEADER-2024" = hdr(2),
    "SB-P01-T01-GONE-2024"   = data.frame(OBJECTID = "OID-000000000000000001", B = 1)))
  make_release(file.path(root, "new"), list(
    "F9-P00-T00-HEADER-2023" = hdr(3),
    "F9-P00-T00-HEADER-2024" = cbind(hdr(4), EXEMPT = "501c3"),
    "F9-P00-T00-HEADER-2025" = hdr(5),
    "SB-P01-T00-NEW-2024"    = data.frame(OBJECTID = "OID-000000000000000001", C = 2)))
  cc_old <- data.frame(xpath = c("/a", "/b"), variable_name = c("V_A", "V_B"), rdb_table = c("T1", "T1"), multi_value = c("FALSE", "FALSE"))
  cc_new <- data.frame(xpath = c("/a", "/b", "/c"), variable_name = c("V_A", "V_B2", "V_C"), rdb_table = c("T1", "T0", "T0"), multi_value = c("TRUE", "FALSE", "FALSE"))

  cmp <- compare_releases(file.path(root, "old"), file.path(root, "new"), cc_old, cc_new, labels = c("v1", "v2"))
  expect_s3_class(cmp, "release_comparison")
  expect_equal(cmp$tables$added$table, "SB-P01-T00-NEW")
  expect_equal(cmp$tables$dropped$table, "SB-P01-T01-GONE")
  expect_equal(cmp$meta$years_new, "2023-2025")
  # EXEMPT added in 2024 only; 2025 is new, so it is not a column change
  expect_equal(cmp$columns[change == "added"]$column, "EXEMPT")
  expect_equal(cmp$columns[change == "added"]$years, "2024")
  d <- cmp$dims[table == "F9-P00-T00-HEADER"]
  expect_equal(d[year == 2024]$d_rows, 2)
  expect_equal(d[year == 2023]$d_rows, 0)
  expect_true(is.na(d[year == 2025]$rows_old))
  expect_equal(sum(cmp$filings$new), 12)
  expect_equal(sum(cmp$filings$old), 5)
  expect_equal(cmp$labels$new_xpaths$xpath, "/c")
  expect_equal(cmp$labels$renamed$to, "V_B2")
  expect_equal(cmp$labels$moved$xpath, "/b")
  expect_equal(cmp$labels$multi_value$xpath, "/a")

  md <- file.path(root, "NOTES.md")
  txt <- write_release_notes(cmp, md, title = "v2", notes = "Hand-written context.")
  expect_true(file.exists(md))
  for (h in c("# Release notes: v2", "## Notes", "Hand-written context.", "## Summary", "## Filings by tax year",
              "## Tables added and dropped", "## Column changes", "## Row-count changes", "## Concordance changes"))
    expect_true(grepl(h, txt, fixed = TRUE), info = h)
  expect_true(grepl("`EXEMPT`", txt, fixed = TRUE))
  expect_true(grepl("- **Tables:** 1 added, 1 dropped.", txt, fixed = TRUE))
})

test_that("compare_releases() works without concordances or filing counts", {
  root <- tempfile("rel2"); on.exit(unlink(root, recursive = TRUE))
  make_release(file.path(root, "a"), list("X-P01-T01-T-2024" = data.frame(OBJECTID = "OID-1", A = 1)))
  make_release(file.path(root, "b"), list("X-P01-T01-T-2024" = data.frame(OBJECTID = "OID-1", A = 1)))
  cmp <- compare_releases(file.path(root, "a"), file.path(root, "b"), filings = FALSE)
  expect_null(cmp$labels); expect_null(cmp$filings)
  expect_equal(nrow(cmp$columns), 0)
  txt <- write_release_notes(cmp)
  expect_true(grepl("_None._", txt, fixed = TRUE))
})
