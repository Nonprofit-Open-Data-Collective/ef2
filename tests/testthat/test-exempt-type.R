# Fixture archive attached as EFILE2024, the catalog name exempt_type_sql() reads.
# f: FLATXML rows (OBJECTID, XPATH2, VALUE); a: ATTRIBUTES rows (OBJECTID, xpath,
# attr_name, attr_value).
exempt_fixture <- function( f, a ) {
  con <- DBI::dbConnect( duckdb::duckdb() )
  DBI::dbExecute( con, "ATTACH ':memory:' AS EFILE2024" )
  f$TYPE      <- rep( "terminal", nrow( f ) )
  f$RDB_TABLE <- rep( "F9-P00-T00-HEADER", nrow( f ) )
  DBI::dbWriteTable( con, DBI::Id( catalog = "EFILE2024", table = "FLATXML" ), f )
  DBI::dbWriteTable( con, DBI::Id( catalog = "EFILE2024", table = "ATTRIBUTES" ), a )
  con
}

exempt_types <- function( con ) {
  d <- DBI::dbGetQuery( con, exempt_type_sql( 2024 ) )
  stats::setNames( d$F9_00_ORG_EXEMPT_TYPE, d$OBJECTID )[ order( d$OBJECTID ) ]
}

R  <- "/Return/ReturnData/IRS990/"
EZ <- "/Return/ReturnData/IRS990EZ/"

test_that("the 501(c) subsection is read from its attribute, in both spellings and both forms", {
  a <- data.frame(
    OBJECTID   = c( "A", "B", "C", "D" ),
    xpath      = c( paste0( R,  "Organization501cInd" ), paste0( EZ, "Organization501cInd" ),
                    paste0( R,  "Organization501c" ),    paste0( EZ, "Organization501c" ) ),
    attr_name  = c( "organization501cTypeTxt", "organization501cTypeTxt",
                    "typeOf501cOrganization",  "typeOf501cOrganization" ),
    attr_value = c( "6", "4", "19", "7" ) )
  f <- data.frame( OBJECTID = "A", XPATH2 = paste0( R, "Organization501cInd" ), VALUE = "X" )
  con <- exempt_fixture( f, a )
  on.exit( DBI::dbDisconnect( con, shutdown = TRUE ) )

  expect_identical( exempt_types( con ),
                    c( A = "501c6", B = "501c4", C = "501c19", D = "501c7" ) )
})

test_that("the two 501(c)(3) encodings land on the same value", {
  # TY2010 on: a checkbox, in either element spelling. TY2009: "3" in the attribute.
  f <- data.frame(
    OBJECTID = c( "A", "B" ),
    XPATH2   = c( paste0( R, "Organization501c3Ind" ), paste0( EZ, "Organization501c3" ) ),
    VALUE    = "X" )
  a <- data.frame( OBJECTID = "C", xpath = paste0( R, "Organization501c" ),
                   attr_name = "typeOf501cOrganization", attr_value = "3" )
  con <- exempt_fixture( f, a )
  on.exit( DBI::dbDisconnect( con, shutdown = TRUE ) )

  expect_identical( exempt_types( con ), c( A = "501c3", B = "501c3", C = "501c3" ) )
})

test_that("4947(a)(1) and the unobserved 527 placeholder are covered", {
  f <- data.frame(
    OBJECTID = c( "A", "B", "C", "D" ),
    XPATH2   = c( paste0( R,  "Organization4947a1NotPFInd" ),
                  paste0( EZ, "Organization4947a1" ),
                  paste0( R,  "Form990PartI/Organization4947a1" ),
                  paste0( R,  "Organization527Ind" ) ),
    VALUE    = "X" )
  a <- data.frame( OBJECTID = character(), xpath = character(),
                   attr_name = character(), attr_value = character() )
  con <- exempt_fixture( f, a )
  on.exit( DBI::dbDisconnect( con, shutdown = TRUE ) )

  expect_identical( exempt_types( con ),
                    c( A = "4947a1", B = "4947a1", C = "4947a1", D = "527" ) )
})

test_that("explicit negatives, blanks, other elements and other forms set no status", {
  f <- data.frame(
    OBJECTID = c( "A", "B", "C", "D" ),
    XPATH2   = c( paste0( R, "Organization501c3Ind" ), paste0( R, "Organization501c3Ind" ),
                  paste0( R, "Organization501c3IndOther" ),
                  "/Return/ReturnData/IRS990ScheduleA/Organization501c3Ind" ),
    VALUE    = c( "0", " ", "X", "X" ) )
  a <- data.frame( OBJECTID = "E", xpath = paste0( R, "Organization501cInd" ),
                   attr_name = "organization501cTypeTxt", attr_value = "" )
  con <- exempt_fixture( f, a )
  on.exit( DBI::dbDisconnect( con, shutdown = TRUE ) )

  expect_length( exempt_types( con ), 0L )
})

test_that("irs:-prefixed paths are matched (EF2-11)", {
  f <- data.frame( OBJECTID = "A",
                   XPATH2 = "/irs:Return/irs:ReturnData/irs:IRS990/irs:Organization501c3Ind",
                   VALUE = "X" )
  a <- data.frame( OBJECTID = "B",
                   xpath = "/irs:Return/irs:ReturnData/irs:IRS990EZ/irs:Organization501cInd",
                   attr_name = "organization501cTypeTxt", attr_value = "12" )
  con <- exempt_fixture( f, a )
  on.exit( DBI::dbDisconnect( con, shutdown = TRUE ) )

  expect_identical( exempt_types( con ), c( A = "501c3", B = "501c12" ) )
})

test_that("add_exempt_type() joins the status after the checkboxes and keeps every row", {
  f <- data.frame( OBJECTID = "A", XPATH2 = paste0( R, "Organization501c3Ind" ), VALUE = "X" )
  a <- data.frame( OBJECTID = "B", xpath = paste0( R, "Organization501cInd" ),
                   attr_name = "organization501cTypeTxt", attr_value = "6" )
  con <- exempt_fixture( f, a )
  on.exit( DBI::dbDisconnect( con, shutdown = TRUE ) )

  hdr <- data.frame( OBJECTID = c( "A", "B", "C" ),
                     F9_00_EXEMPT_STAT_501C3_X = c( "X", "", "" ),
                     F9_00_EXEMPT_STAT_501C_X  = c( "", "X", "" ),
                     F9_00_LATER = "z" )
  DBI::dbWriteTable( con, "HDR", hdr )
  out <- dplyr::collect( add_exempt_type( dplyr::tbl( con, "HDR" ), 2024, con ) )
  out <- out[ order( out$OBJECTID ), ]

  expect_identical( colnames( out ),
                    c( "OBJECTID", "F9_00_EXEMPT_STAT_501C3_X", "F9_00_EXEMPT_STAT_501C_X",
                       "F9_00_ORG_EXEMPT_TYPE", "F9_00_LATER" ) )
  expect_identical( out$F9_00_ORG_EXEMPT_TYPE, c( "501c3", "501c6", NA ) )
})

test_that("several subsection values on one filing are kept, sorted and joined with ';'", {
  # A and B: two distinct values, in either order. C: the same value twice.
  a <- data.frame( OBJECTID = c( "A", "A", "B", "B", "C", "C" ),
                   xpath = paste0( R, "Organization501cInd" ),
                   attr_name = "organization501cTypeTxt",
                   attr_value = c( "6", "4", "4", "6", "7", "7" ) )
  f <- data.frame( OBJECTID = character(), XPATH2 = character(), VALUE = character() )
  con <- exempt_fixture( f, a )
  on.exit( DBI::dbDisconnect( con, shutdown = TRUE ) )

  expect_identical( exempt_types( con ),
                    c( A = "501c4;501c6", B = "501c4;501c6", C = "501c7" ) )

  DBI::dbWriteTable( con, "HDR", data.frame( OBJECTID = c( "A", "C" ) ) )
  out <- dplyr::collect( add_exempt_type( dplyr::tbl( con, "HDR" ), 2024, con ) )
  expect_identical( out$F9_00_ORG_EXEMPT_TYPE[ order( out$OBJECTID ) ], c( "501c4;501c6", "501c7" ) )
})
