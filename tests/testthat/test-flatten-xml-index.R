test_that("flatten_xml() strips repeat indices of any width from XPATH2 (EF2-16)", {
  # 100,001 repeats, so the last one carries a 6-digit index: /Return/Grp[100001]/Amt
  n   <- 100001
  raw <- paste0( "<Return>", strrep( "<Grp><Amt>1</Amt></Grp>", n ), "</Return>" )
  doc <- xml2::read_xml( raw )
  ccf <- data.frame( XPATH = "/Return/Grp/Amt", VARIABLE_NAME = "GRP_AMT",
                     RDB_TABLE = "T-GRP", stringsAsFactors = FALSE )

  d <- flatten_xml( doc, url = "https://x/202300000000000001_public.xml", ccf = ccf )

  expect_true( "/Return/Grp[100001]/Amt" %in% d$XPATH )
  expect_false( any( grepl( "[", d$XPATH2, fixed = TRUE ) ) )
  amt <- d[ d$XPATH2 == "/Return/Grp/Amt", ]
  expect_equal( nrow(amt), n )
  expect_true( all( amt$VARIABLE_NAME == "GRP_AMT" ) )
  expect_true( all( amt$RDB_TABLE == "T-GRP" ) )
})
