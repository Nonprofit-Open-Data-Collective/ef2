
#' Retrieve the Concordance File
#'
#' Downloads the master concordance file from GitHub or loads a packaged version.
#'
#' @param gh Logical; if TRUE, fetches the concordance from GitHub.
#' @return A data.table or data.frame containing the concordance.
#' @export
get_concordance <- function( gh=TRUE ){
  concordance <- NULL
  if( gh ){
    base <- "https://raw.githubusercontent.com/"
    gh.id <- "Nonprofit-Open-Data-Collective/"
    rn <- "irs-efile-master-concordance-file/refs/heads/master/"
    fn <- "concordance.csv"
    url <- paste0( base, gh.id, rn, fn )
    tmp <- tempfile( fileext = ".csv" )
    utils::download.file( url, tmp, quiet = TRUE )
    concordance <- data.table::fread( tmp, showProgress = FALSE )
  }
  if( is.null(concordance) || ! gh ){ utils::data(concordance, package = "ef2", envir = environment()) }
  return( concordance )
}

#' Prepare a concordance crosswalk (uppercase colnames)
#'
#' @param ccf Optional concordance; if NULL, loads via `get_concordance()`.
#' @return Data frame with columns XPATH, VARIABLE_NAME, RDB_TABLE.
#' @export
prep_concordance <- function( ccf=NULL ){
  if( is.null(ccf) ){ ccf <- get_concordance() }
  ccf <- as.data.frame( ccf )
  ccf <- ccf[c("xpath","variable_name","rdb_table")]
  names(ccf) <- toupper(names(ccf))
  return(ccf)
}

#' Refresh the packaged concordance from GitHub
#'
#' Package-maintenance helper that replaces the packaged `concordance` dataset
#' (`data/concordance.rda`) with the most up-to-date master concordance file
#' from GitHub.
#'
#' @details Downloads the master concordance CSV, normalizes column names to
#'   lower case, optionally refreshes the raw copy at
#'   `inst/extdata/concordance.csv`, and writes the compressed
#'   `data/concordance.rda` via [usethis::use_data()]. Run this from the
#'   package source root during development, then rebuild/reinstall the package
#'   to pick up the new data. Requires the `usethis` package.
#'
#' @param raw_copy Logical; if TRUE (default) also refresh the raw CSV at
#'   `inst/extdata/concordance.csv`.
#' @return Invisibly, the refreshed concordance as a `data.table`.
#' @seealso [get_concordance()] to load the concordance at run time.
#' @export
update_concordance <- function( raw_copy = TRUE ){
  if( ! requireNamespace( "usethis", quietly = TRUE ) ){
    stop( "update_concordance() requires the 'usethis' package. ",
          "Install it with install.packages('usethis')." )
  }

  base  <- "https://raw.githubusercontent.com/"
  gh.id <- "Nonprofit-Open-Data-Collective/"
  rn    <- "irs-efile-master-concordance-file/refs/heads/master/"
  fn    <- "concordance.csv"
  url   <- paste0( base, gh.id, rn, fn )

  tmp <- tempfile( fileext = ".csv" )
  utils::download.file( url, tmp, quiet = TRUE )

  concordance <- data.table::fread( tmp, showProgress = FALSE )
  names( concordance ) <- tolower( names( concordance ) )

  # Normalize character columns to ASCII (transliterate smart quotes/dashes,
  # drop any remaining non-ASCII) so the packaged data stays portable.
  char_cols <- names( concordance )[ vapply( concordance, is.character, logical(1) ) ]
  for( col in char_cols ){
    concordance[[col]] <- iconv( concordance[[col]], to = "ASCII//TRANSLIT", sub = "" )
  }

  if( raw_copy ){
    dest <- file.path( "inst", "extdata", "concordance.csv" )
    dir.create( dirname( dest ), showWarnings = FALSE, recursive = TRUE )
    file.copy( tmp, dest, overwrite = TRUE )
  }

  usethis::use_data( concordance, overwrite = TRUE, compress = "xz" )
  message( "Refreshed data/concordance.rda (", nrow( concordance ),
           " rows, ", ncol( concordance ), " columns)." )
  invisible( concordance )
}

#' Check whether the packaged concordance is current
#'
#' Compares the concordance shipped with the package (`data(concordance)`) to
#' the current master concordance file on GitHub, so a stale packaged copy can
#' be detected (e.g. at build/check time).
#'
#' @param verbose Logical; if TRUE (default) messages a short summary.
#' @return Logical `TRUE` if the packaged data matches GitHub, `FALSE` if it is
#'   out of date, or `NA` (with a warning) if the GitHub version could not be
#'   retrieved (e.g. offline).
#' @seealso [update_concordance()] to refresh the packaged data.
#' @export
concordance_is_current <- function( verbose = TRUE ){
  base  <- "https://raw.githubusercontent.com/"
  gh.id <- "Nonprofit-Open-Data-Collective/"
  rn    <- "irs-efile-master-concordance-file/refs/heads/master/"
  url   <- paste0( base, gh.id, rn, "concordance.csv" )

  tmp <- tempfile( fileext = ".csv" )
  ok <- tryCatch( { utils::download.file( url, tmp, quiet = TRUE ); TRUE },
                  error = function(e) FALSE, warning = function(w) FALSE )
  if( ! ok ){
    warning( "Could not download the GitHub concordance; currency unknown." )
    return( NA )
  }

  gh <- data.table::fread( tmp, showProgress = FALSE )
  names( gh ) <- tolower( names( gh ) )

  pkg <- get_concordance( gh = FALSE )   # packaged data(concordance)

  current <- nrow( gh ) == nrow( pkg ) &&
             ncol( gh ) == ncol( pkg ) &&
             setequal( gh[["xpath"]], pkg[["xpath"]] )

  if( verbose ){
    if( isTRUE( current ) ){
      message( "Packaged concordance is current (", nrow( pkg ), " rows)." )
    } else {
      message( "Packaged concordance is OUT OF DATE: packaged ",
               nrow( pkg ), " rows / ", ncol( pkg ), " cols vs GitHub ",
               nrow( gh ), " rows / ", ncol( gh ), " cols. ",
               "Run update_concordance() to refresh." )
    }
  }
  return( current )
}
