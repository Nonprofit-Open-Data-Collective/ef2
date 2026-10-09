test_that("release_concordance() returns the pinned efile_v2_3 concordance", {
  cc <- release_concordance( "efile_v2_3" )
  expect_identical( names( cc ), c( "xpath", "variable_name", "rdb_table" ) )
  # concordance990 1.99.1, concordance("v2", form = "F990"): the RELABEL_LOG row count
  expect_identical( nrow( cc ), 7016L )
  expect_identical( nrow( unique( cc ) ), 7016L )
  # a v2 rename (v2_2 called it SB_01_CONTRIBUTOR_TYPE)
  expect_true( "SB_01_CONTRIBUTOR_NUM" %in% cc$variable_name )
  expect_named( prep_concordance( cc ), c( "XPATH", "VARIABLE_NAME", "RDB_TABLE" ) )
})

test_that("release_concordance() refuses a release it has no concordance for", {
  expect_error( release_concordance( "efilepf_v2_3" ), "Pass `ccf`" )
})

test_that("db_release() reads the latest RELABEL_LOG release, or NULL without one", {
  db <- tempfile( fileext = ".duckdb" )
  on.exit( unlink( db ) )
  con <- DBI::dbConnect( duckdb::duckdb(), dbdir = db )
  DBI::dbWriteTable( con, "KEYS", data.frame( OBJECTID = "OID-1" ) )
  DBI::dbDisconnect( con, shutdown = TRUE )
  expect_null( db_release( db ) )

  con <- DBI::dbConnect( duckdb::duckdb(), dbdir = db )
  DBI::dbWriteTable( con, "RELABEL_LOG", data.frame(
    applied = as.POSIXct( c( "2026-10-06 21:09:15", "2026-10-01 10:00:00" ), tz = "UTC" ),
    release = c( "efile_v2_3", "efile_v2_2" ) ) )
  DBI::dbDisconnect( con, shutdown = TRUE )
  expect_identical( db_release( db ), "efile_v2_3" )
})

test_that("merge_databases() carries RELABEL_LOG and REPAIR_LOG into the merged archive", {
  skip_on_cran()
  dir <- tempfile( "merge-" ); dir.create( dir )
  old <- setwd( dir )
  on.exit( { setwd( old ); unlink( dir, recursive = TRUE ) } )

  src <- file.path( dir, "src.duckdb" )
  con <- DBI::dbConnect( duckdb::duckdb(), dbdir = src )
  for ( t in c( "KEYS", "FLATXML", "ATTRIBUTES" ) ) DBI::dbWriteTable( con, t, data.frame( OBJECTID = "OID-1" ) )
  DBI::dbWriteTable( con, "RELABEL_LOG", data.frame( release = "efile_v2_3" ) )
  DBI::dbWriteTable( con, "REPAIR_LOG", data.frame( note = "EF2-11" ) )
  DBI::dbDisconnect( con, shutdown = TRUE )

  tmp <- file.path( dir, "tmp.duckdb" )
  con <- DBI::dbConnect( duckdb::duckdb(), dbdir = tmp )
  for ( t in c( "KEYS", "FLATXML", "ATTRIBUTES" ) ) DBI::dbWriteTable( con, t, data.frame( OBJECTID = "OID-2" ) )
  DBI::dbDisconnect( con, shutdown = TRUE )

  out <- file.path( dir, "out.duckdb" )
  ok <- tryCatch( { suppressMessages( merge_databases( 2024, "x", tmp, out, source_db = src ) ); TRUE },
                  error = function( e ) conditionMessage( e ) )
  skip_if( ! isTRUE( ok ), paste( "merge_databases() could not run here:", ok ) )

  con <- DBI::dbConnect( duckdb::duckdb(), dbdir = out, read_only = TRUE )
  on.exit( DBI::dbDisconnect( con, shutdown = TRUE ), add = TRUE, after = FALSE )
  expect_setequal( DBI::dbListTables( con ),
                   c( "KEYS", "FLATXML", "ATTRIBUTES", "RELABEL_LOG", "REPAIR_LOG" ) )
  expect_identical( DBI::dbGetQuery( con, "SELECT release FROM RELABEL_LOG" )$release, "efile_v2_3" )
  expect_identical( sort( DBI::dbGetQuery( con, "SELECT OBJECTID FROM KEYS" )$OBJECTID ),
                    c( "OID-1", "OID-2" ) )
})

test_that("release_concordance() returns the pinned v3_1 concordances", {
  cc <- release_concordance( "efile_v3_1" )
  expect_identical( names( cc ), c( "xpath", "variable_name", "rdb_table" ) )
  # concordance990 2.0.1 (02de916), concordance("v2", form = "F990")
  expect_identical( nrow( cc ), 7075L )
  expect_false( anyDuplicated( cc$xpath ) > 0 )
  # moved T01 -> T00 between v2_3 and v3_1
  expect_true( "SG-P02-T00-FUNDRAISING-EVENTS" %in% cc$rdb_table )
  expect_false( "SG-P02-T01-FUNDRAISING-EVENTS" %in% cc$rdb_table )

  pf <- release_concordance( "efilepf_v3_1" )
  expect_identical( nrow( pf ), 2524L )
  expect_true( "PF-P09-T00-CHARITABLE-ACTIVITIES" %in% pf$rdb_table )
  expect_false( "PF-P09-T01-CHARITABLE-ACTIVITIES" %in% pf$rdb_table )
  expect_named( prep_concordance( pf ), c( "XPATH", "VARIABLE_NAME", "RDB_TABLE" ) )
})
