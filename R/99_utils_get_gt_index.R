##########
##########  IDENTIFY THE MOST CURRENT INDEX FILE FROM AWS
##########


#' @title Get Last N Dates
#' @description Generates a sequence of the last N dates in "YYYY-MM-DD" format.
#' @param N An integer specifying the number of days to generate.
#' @return A character vector of dates in "YYYY-MM-DD" format.
#' @examples
#' get_last_n_dates(30)
#' @export
get_last_n_dates <- function(N = 30) {
  today <- Sys.Date()
  last_n_dates <- seq(today, by = "-1 day", length.out = N)
  formatted_dates <- as.character(last_n_dates)
  return(formatted_dates)
}

#' @title Validate URL Status
#' @description Checks if a given URL is valid by sending an HTTP HEAD request.
#' @param url A character string representing the URL to validate.
#' @return A logical value indicating if the URL is valid (HTTP status 200).
#' @examples
#' base <- "https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/"
#' fn_01 <- "index_all_years_efiledata_xmls_created_on_2024-12-23.csv"
#' fn_02 <- "index_all_years_efiledata_xmls_created_on_2024-12-24.csv"
#' url_01 <- paste0( base, fn_01 )  
#' url_02 <- paste0( base, fn_02 )  
#' url_is_valid( url_01 )   # file exists
#' url_is_valid( url_02 )   # file does not exist
#' @export
url_is_valid <- function(url) {
  hd <- httr::HEAD(url)
  status <- hd$all_headers[[1]]$status
  return(status == "200")
}

#' @title List Index Files in the GTDC S3 Bucket
#' @description Lists every file under `Indices/990xmls/` in the Giving
#'  Tuesday Data Commons bucket with a plain HTTPS request. No AWS account,
#'  key, or CLI is needed: the bucket allows anonymous listing.
#' @details Follows S3 continuation tokens, so the result is complete even
#'  past 1,000 files. Returns `NULL` (rather than an error) if the listing is
#'  refused or unreachable -- e.g. if the bucket stops allowing anonymous
#'  listing -- so callers can fall back to probing URLs by date.
#' @param timeout Seconds to wait for each listing request.
#' @return A character vector of object keys (e.g.
#'  `"Indices/990xmls/index_all_years_efiledata_xmls_created_on_2024-12-23.csv"`),
#'  or `NULL` if the bucket could not be listed.
#' @examples
#' \dontrun{
#' keys <- list_gt_indices()
#' extract_filenames_full( keys )
#' }
#' @export
list_gt_indices <- function( timeout = 30 ) {
  base  <- "https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/"
  keys  <- character(0)
  token <- NULL
  repeat {
    query <- list( `list-type` = 2, prefix = "Indices/990xmls/",
                   `continuation-token` = token )
    resp <- tryCatch( httr::GET( base, query = query, httr::timeout( timeout ) ),
                      error = function(e) NULL )
    if ( is.null(resp) || httr::status_code(resp) != 200 ) { return(NULL) }
    x <- xml2::read_xml( httr::content( resp, as = "text", encoding = "UTF-8" ) )
    xml2::xml_ns_strip(x)
    keys <- c( keys, xml2::xml_text( xml2::xml_find_all( x, "//Contents/Key" ) ) )
    truncated <- xml2::xml_text( xml2::xml_find_first( x, "//IsTruncated" ) )
    if ( !identical( truncated, "true" ) ) { break }
    token <- xml2::xml_text( xml2::xml_find_first( x, "//NextContinuationToken" ) )
  }
  return(keys)
}

#' @title Find Most Recent GTDC Index of a Given Type
#' @description Shared engine for [find_current_index_full()] and
#'  [find_current_index_batch()].
#' @details Lists the bucket with [list_gt_indices()] and takes the newest
#'  matching CSV, however old it is. If the listing is unavailable, falls back
#'  to probing one URL per day for the last `days` days. A message reports the
#'  index date when it is older than `days`, because the GTDC indices are not
#'  always refreshed (the newest was 2024-12-23 as of October 2026).
#' @param type `"full"` (all years) or `"batch"` (latest only).
#' @param days Days to probe in the fallback, and the age past which a stale
#'  index is reported.
#' @return The index URL, or `NA` if none was found.
#' @keywords internal
find_current_index <- function( type = c("full","batch"), days = 100 ) {
  type <- match.arg(type)
  base <- "https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/"
  stem <- if ( type == "full" ) "index_all_years_efiledata_xmls_created_on_" else
                                "index_latest_only_efiledata_xmls_created_on_"
  extract <- if ( type == "full" ) extract_filenames_full else extract_filenames_batch

  fns  <- NA_character_
  keys <- list_gt_indices()
  if ( !is.null(keys) ) {
    fns <- extract(keys)
    fns <- fns[ !is.na(fns) ]
  }

  if ( length(fns) > 0 && !all( is.na(fns) ) ) {
    fn  <- fns[ find_most_recent_date( extract_dates(fns) ) ]
    url <- paste0( base, fn )
  } else {
    message( "Could not list the GTDC bucket; probing the last ", days, " days by date." )
    urls <- paste0( base, stem, get_last_n_dates(days), ".csv" )
    url  <- NA_character_
    for ( u in urls ) {
      if ( url_is_valid(u) ) { url <- u; break }
    }
    if ( is.na(url) ) { return(NA) }
  }

  age <- as.numeric( Sys.Date() - as.Date( extract_dates(url) ) )
  if ( age > days ) {
    message( "Most recent GTDC ", type, " index is dated ", extract_dates(url),
             " (", age, " days old)." )
  }
  return(url)
}

#' @title Find Most Recent AWS Full Index
#' @description Identifies the most recent AWS index file (all years).
#' @details Lists the bucket anonymously ([list_gt_indices()]); if that fails,
#'  falls back to probing the last `days` days by date. See
#'  [find_current_index()].
#' @param days An integer: days to probe in the fallback, and the age past
#'  which a stale index is reported.
#' @return A character string representing the URL of the most recent index file, or NA if none found.
#' @examples
#' find_current_index_full(100)
#' @export
find_current_index_full <- function(days = 100) {
  find_current_index( "full", days )
}

#' @title Find Most Recent AWS Batch Index
#' @description Identifies the most recent AWS batch index file (only new files).
#' @details Lists the bucket anonymously ([list_gt_indices()]); if that fails,
#'  falls back to probing the last `days` days by date. See
#'  [find_current_index()].
#' @param days An integer: days to probe in the fallback, and the age past
#'  which a stale index is reported.
#' @return A character string representing the URL of the most recent index file, or NA if none found.
#' @examples
#' find_current_index_batch(100)
#' @export
find_current_index_batch <- function(days = 100) {
  find_current_index( "batch", days )
}

#' @title Get URL Status
#' @description Retrieves the HTTP status of a given URL.
#' @param url A character string representing the URL to check.
#' @return A data frame containing the URL, its existence status, and the HTTP status code.
#' @examples
#' get_url_status("https://example.com")
#' @export
get_url_status <- function(url) {
  hd <- httr::HEAD(url)
  status <- hd$all_headers[[1]]$status
  row <- data.frame(url = url, exists = status == "200", status = status)
  return(row)
}

#' @title Get URL Status for Multiple Days
#' @description Checks the status of AWS index URLs for the last specified number of days.
#' @param days An integer specifying the number of days to check.
#' @return A data frame containing the status of URLs for each day.
#' @examples
#' get_url_status_df(30)
#' @export
get_url_status_df <- function(days = 30) {
  base <- "https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/"
  fn   <- "index_all_years_efiledata_xmls_created_on_"
  dd   <- get_last_n_dates(days)
  urls <- paste0( base, fn, dd, ".csv" )
  mL   <- purrr::map(urls, get_url_status)
  dff  <- dplyr::bind_rows(mL)
  return(dff)
}

#' @title Download Current AWS Index
#' @description Downloads the most recent AWS index file.
#' @return None. Downloads the file as "INDEX.CSV" in the working directory.
#' @examples
#' \dontrun{
#' fn <- download_current_index_full()
#' index <- data.table::fread( fn )
#' split_index( index )
#' }
#' @export
download_current_index_full <- function() {
  url <- find_current_index_full()
  fn <- extract_filenames_full( url )
  options( timeout = 600 )
  download.file( url, destfile = fn )
  return( fn )
}

#' @title Load the full IRS 990 e-filer index from the Data Commons
#'
#' @description Downloads the most recent "all years" IRS 990 e-file index
#'  published to the Giving Tuesday Data Commons and returns it as a
#'  `data.table`. This is the complete index of every available filing.
#'
#' @details Locates the newest `index_all_years_...` CSV by walking backward
#'  from today (see [find_current_index_full()]), downloads it, sorts by
#'  `ReturnTs`, and drops duplicate `URL`s (keeping the most recent). A count
#'  of filings per `TaxYear` is printed as a side effect.
#'
#' @param TIMEOUT Integer. Download timeout in seconds (default 600).
#' @return A `data.table` with one row per filing. See [index] for the column
#'  definitions.
#' @seealso [get_current_index_batch()] for the incremental "latest only"
#'  index; [find_current_index_full()] to resolve just the URL.
#' @examples
#' \dontrun{
#' df <- get_current_index_full()
#' }
#' @export
get_current_index_full <- function( TIMEOUT=600 ) {
  url <- find_current_index_full()
  options(timeout = TIMEOUT)
  dt <- data.table::fread(url) |> dplyr::arrange( ReturnTs )
  dt <- dt[ ! duplicated(dt$URL,fromLast=TRUE) , ]
  cat( table( dt$TaxYear ) |> knitr::kable(), sep="\n" )
  return(dt)
}


#' @title Load the most recent IRS 990 e-filer batch index from the Data Commons
#'
#' @description Downloads the most recent "latest only" IRS 990 e-file index
#'  published to the Giving Tuesday Data Commons and returns it as a
#'  `data.table`. Unlike [get_current_index_full()], this contains only the
#'  filings that are new to the most recent batch.
#'
#' @details Locates the newest `index_latest_only_...` CSV by walking backward
#'  from today (see [find_current_index_batch()]), downloads it, sorts by
#'  `ReturnTs`, and drops duplicate `URL`s (keeping the most recent). A count
#'  of filings per `TaxYear` is printed as a side effect.
#'
#' @param TIMEOUT Integer. Download timeout in seconds (default 600).
#' @return A `data.table` with one row per filing. See [index] for the column
#'  definitions.
#' @seealso [get_current_index_full()] for the complete all-years index;
#'  [find_current_index_batch()] to resolve just the URL.
#' @examples
#' \dontrun{
#' df <- get_current_index_batch()
#' }
#' @export
get_current_index_batch <- function( TIMEOUT=600 ) {
  url <- find_current_index_batch()
  options(timeout = TIMEOUT)
  dt <- data.table::fread(url) |> dplyr::arrange( ReturnTs )
  dt <- dt[ ! duplicated(dt$URL,fromLast=TRUE) , ]
  cat( table( dt$TaxYear ) |> knitr::kable(), sep="\n" )
  return(dt)
}



##########
##########    IF YOU HAVE THE AWS CLI PACKAGE INSTALLED
##########    https://990data.givingtuesday.org/access-via-aws-account-2/
##########


#' @title Get AWS Index List
#' @description Retrieves a list of AWS indices using the AWS CLI.
#' @return A character vector containing the raw output of the AWS CLI command.
#' @examples
#' \dontrun{
#' get_index_list_awscli()
#' }
#' @export
get_index_list_awscli <- function() {
  s3.bash <- 'aws s3 ls s3://gt990datalake-rawdata/Indices/990xmls/ --recursive --no-sign-request'
  bash.out <- system(s3.bash, intern = TRUE)
  return(bash.out)
}

#' @title Extract Index Filenames
#' @description Extracts filenames matching a specific pattern from a vector of strings.
#' @param strings A character vector containing strings to search.
#' @return A character vector of matched filenames.
#' @examples
#' \dontrun{
#' index.list <- get_index_list_awscli()
#' extract_filenames_full( index.list )
#' }
#' @export
extract_filenames_full <- function(strings) {
  pattern <- "index_all_years_efiledata_xmls_created_on_\\d{4}-\\d{2}-\\d{2}\\.csv"
  matches <- regmatches(strings, regexec(pattern, strings)) |> unlist()
  if (length(matches) == 0) {
    return(NA_character_)
  }
  return(matches)
}

#' @title Extract Batch Index Filenames
#' @description Extracts batch index filenames from the list of all files in the GTDC AWS S3 index bucket.
#' @param strings A character vector containing strings to search.
#' @return A character vector of matched filenames.
#' @examples
#' \dontrun{
#' index.list <- get_index_list_awscli()
#' extract_filenames_batch( index.list )
#' }
#' @export
extract_filenames_batch <- function(strings) {
  pattern <- "index_latest_only_efiledata_xmls_created_on_\\d{4}-\\d{2}-\\d{2}\\.csv"
  matches <- regmatches(strings, regexec(pattern, strings)) |> unlist()
  if (length(matches) == 0) {
    return(NA_character_)
  }
  return(matches)
}

#' @title Extract Dates from Filenames
#' @description Extracts dates in "YYYY-MM-DD" format from a vector of strings.
#' @param x A character vector containing filenames.
#' @return A character vector of extracted dates.
#' @examples
#' extract_dates("xmls_created_on_2023-11-19.csv")
#' @export
extract_dates <- function(x) {
  stringr::str_extract(x, "\\d{4}-\\d{2}-\\d{2}")
}

#' @title Find Most Recent Date
#' @description Finds the position of the most recent date in a vector of dates.
#' @param dates A character vector of dates in "YYYY-MM-DD" format.
#' @return An integer indicating the position of the most recent date.
#' @examples
#' dates <- c( "2023-11-18", "2023-11-19", "2024-06-01" )
#' find_most_recent_date( dates )
#' @export
find_most_recent_date <- function(dates) {
  date_objects <- as.Date(dates)
  most_recent <- which.max(date_objects)
  return(most_recent)
}

#' @title Get Current AWS Index Using CLI
#' @description Retrieves the filename of the most recent AWS index.
#' @return A character string representing the filename of the most recent index.
#' @examples
#' \dontrun{
#' get_current_index_full_awscli()
#' }
#' @export
get_current_index_full_awscli <- function() {
  fL <- get_index_list_awscli()
  fns <- extract_filenames_full(fL)
  dates <- extract_dates(fns)
  most.recent <- find_most_recent_date(dates)
  current.index <- fns[most.recent]
  return(current.index)
}

#' @title Get All Batch Index Filenames Using CLI
#' @description Retrieves the filename of the most recent AWS index.
#' @return A character string representing the filename of the most recent index.
#' @examples
#' \dontrun{
#' get_all_batch_indices_awscli()
#' }
#' @export
get_all_batch_indices_awscli <- function() {
  fL <- get_index_list_awscli()
  fns <- extract_filenames_batch(fL)
  return(fns)
}