test_that("get_table_id() is nine digits in groups of three and sorts as text (EF2-17)", {
  x <- c( "/Return/ReturnHeader/Filer/EIN",
          "/Return/G[1]/A",
          "/Return/G[20000]/A",
          "/Return/G[100000]/A",
          "/Return/P[3]/G[7]/A",
          "/Return/G[999999999]/A" )
  id <- get_table_id( x )
  expect_identical( id, c( "TID-000-000-000", "TID-000-000-001", "TID-000-020-000",
                           "TID-000-100-000", "TID-000-000-007", "TID-999-999-999" ) )
  n <- c( 0, 1, 20000, 100000, 7, 999999999 )
  expect_identical( order( id, method = "radix" ), order( n ) )
  expect_error( get_table_id( "/Return/G[1000000000]/A" ), "999,999,999" )
})

test_that("write_table_output() sorts CSV and Parquet by ORG_EIN, OBJECTID, TABLE_ID", {
  con <- DBI::dbConnect( duckdb::duckdb() )
  dest <- tempfile( "tbl-out-" ); dir.create( dest )
  on.exit( { DBI::dbDisconnect( con, shutdown = TRUE ); unlink( dest, recursive = TRUE ) } )
  dest <- normalizePath( dest, winslash = "/" )

  d <- data.frame(
    ORG_EIN  = c( "200", "100", "100", "100", "100" ),
    OBJECTID = c( "1",   "3",   "2",   "2",   "2"   ),
    TABLE_ID = c( "TID-000-000-001", "TID-000-000-001", "TID-000-100-000",
                  "TID-000-020-000", "TID-000-000-002" ),
    V        = c( "e", "d", "c", "b", "a" ) )
  DBI::dbWriteTable( con, "SRC", d )
  write_table_output( dplyr::tbl( con, "SRC" ), "T-TEST", 2023, con,
                      output = "both", dest = dest )

  want <- c( "a", "b", "c", "d", "e" )
  csv  <- DBI::dbGetQuery( con, sprintf( "SELECT V FROM read_csv('%s/T-TEST-2023.CSV', all_varchar = true)", dest ) )
  pq   <- DBI::dbGetQuery( con, sprintf( "SELECT V FROM read_parquet('%s/T-TEST-2023.parquet')", dest ) )
  expect_identical( csv$V, want )
  expect_identical( pq$V,  want )

  # a T00 table has no TABLE_ID: the remaining keys still apply, no warning
  DBI::dbExecute( con, "CREATE TABLE SRC0 AS SELECT ORG_EIN, OBJECTID, V FROM SRC WHERE TABLE_ID = 'TID-000-000-001'" )
  expect_silent( write_table_output( dplyr::tbl( con, "SRC0" ), "T-TEST0", 2023, con,
                                     output = "csv", dest = dest ) )
  csv0 <- DBI::dbGetQuery( con, sprintf( "SELECT V FROM read_csv('%s/T-TEST0-2023.CSV', all_varchar = true)", dest ) )
  expect_identical( csv0$V, c( "d", "e" ) )
})
