#' Open a DuckDB database connection with S3 support
#'
#' @param s3_region AWS region (default "us-east-1").
#' @param s3_endpoint S3 endpoint domain (default "s3.amazonaws.com").
#'   Use "s3.dualstack.us-east-1.amazonaws.com" for dualstack URLs.
#' @param anonymous Logical; TRUE for anonymous S3 access.
#' @return DBI connection object with httpfs configured for S3.
#' @export
open_database <- function(s3_region = "us-east-1",
                          s3_endpoint = "s3.amazonaws.com",
                          anonymous = TRUE) {

  duck.driver <- duckdb::duckdb()
  con <- DBI::dbConnect(duck.driver, dbdir = ":memory:")

  DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs;")
  DBI::dbExecute(con, paste0("SET s3_region='", s3_region, "';"))
  DBI::dbExecute(con, paste0("SET s3_endpoint='", s3_endpoint, "';"))

  if (anonymous) {
    DBI::dbExecute(con, "SET s3_access_key_id='';")
    DBI::dbExecute(con, "SET s3_secret_access_key='';")
  }

  return(con)
}



#' Attach an S3-hosted DuckDB database by filename
#'
#' @param filename DuckDB filename within s3://nccs-efile/duckdb/.
#' @param version Optional S3 version subfolder under duckdb/ (e.g. "efile_v2_1").
#' @param anonymous Logical for anonymous access.
#' @return DBI connection with attached database.
#' @export
get_s3_database <- function( filename, version=NULL, anonymous = TRUE ) {
  s3_base <- "s3://nccs-efile/duckdb/" 
  if( ! is.null(version) ){ 
    s3_base <- paste0( s3_base, version, "/" ) 
  }
  s3_path <- paste0( s3_base, filename )
  con <- open_database( anonymous = anonymous )
  dbname <- gsub( "\\.duckdb", "", filename )
  message( paste0( "Attached Database: ", dbname ) )
  dbname <- gsub("[^A-Za-z0-9_]", "_", dbname)
  SQL <- paste0( "ATTACH '", s3_path, "' AS ", dbname, ";" )
  DBI::dbExecute( con, SQL )
  table.names <- DBI::dbListTables( con )
  message( paste0( "Table Names: ", paste0( table.names, collapse = "; " ) ) )
  SQL <- paste0( "SELECT count(*) AS num_rows FROM ", dbname, ".KEYS;" )
  n_rows <- DBI::dbGetQuery( con, SQL )
  message( paste0( "Unique Returns: ", format( n_rows, big.mark = "," ) ) )
  return( con )
}

#' Configure AWS credentials for DuckDB session
#'
#' @param con DBI connection to DuckDB.
#' @export
configure_aws_credentials <- function(con) {
  credentials <- aws.signature::locate_credentials()
  DBI::dbExecute( con, paste0( "SET s3_access_key_id='", credentials$key, "';" ) )
  DBI::dbExecute( con, paste0( "SET s3_secret_access_key='", credentials$secret, "';" ) )
  DBI::dbExecute( con, paste0( "SET s3_session_token='", credentials$session_token, "';" ) )
  DBI::dbExecute( con, "SET s3_region='us-east-1';" )
}

#' Write a DuckDB table to CSV on S3 via COPY
#'
#' @param db_tbl A lazy tibble / table reference.
#' @param table_name Character.
#' @param year Integer year.
#' @param con DBI connection.
#' @export
write_csv_to_s3 <- function( db_tbl, table_name, year, con ) {
  fn <- paste0( table_name, "-", year, ".CSV" )
  s3_csv_base <- "s3://nccs-efile/public/v2025_03/"
  s3_csv_path <- paste0( s3_csv_base, fn )
  db_tbl %>% dplyr::compute( "TEMP", temporary = TRUE )
  SQL <- paste0( "COPY TEMP TO '", s3_csv_path, "' WITH ( HEADER, DELIMITER ',' );" )
  DBI::dbExecute( con, SQL )
}
