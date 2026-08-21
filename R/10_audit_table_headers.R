#' Audit TABLE.HEADERS for cross-table misfires
#'
#' `build_rdb_table()` selects a table's rows with an **unanchored** regular
#' expression:
#'
#' ```r
#' hd <- gsub( "//", "/", TABLE.HEADERS[[ table_name ]] )
#' xpath_versions <- paste0( hd, collapse = "|" )
#' dplyr::filter( grepl( xpath_versions, XPATH2 ) )
#' ```
#'
#' Because `grepl()` matches anywhere in the string, a header that is a
#' substring of another header captures rows that belong to a different table.
#' The IRS part naming makes this easy to hit: `Form990ScheduleRPartI` is a
#' substring of `Form990ScheduleRPartII`, `...PartIII` and `...PartIV`, so a
#' pre-2013 `SR-P01` extraction silently absorbs Parts II, III and IV.
#'
#' This is decidable without touching any data: run every header regex against
#' every xpath in the concordance, and compare the `rdb_table` the concordance
#' assigns to each matched xpath against the table being built.
#'
#' @param TABLE.HEADERS Named list of header xpaths per table. Defaults to
#'   `get_table_headers()`.
#' @param cc Concordance data frame with at least `xpath` and `rdb_table`.
#'   Defaults to the packaged `concordance`.
#' @param verbose Print a summary. Default `TRUE`.
#'
#' @return A data frame, one row per (table, foreign table) misfire, with
#'   columns `table_name`, `steals_from`, `n_xpaths`, `example_xpath`. Zero rows
#'   means no header can capture another table's xpaths. Carries attribute
#'   `"unmatched"`: xpaths the concordance assigns to a table whose header does
#'   NOT match them (the opposite failure -- silently missing columns).
#' @export
audit_table_headers <- function( TABLE.HEADERS = get_table_headers(),
                                 cc = NULL,
                                 verbose = TRUE ) {

  if ( is.null( cc ) ) {
    cc <- get0( "concordance", envir = asNamespace( "ef2" ) )
    if ( is.null( cc ) ) stop( "No concordance supplied and none found in the package." )
  }
  if ( !all( c( "xpath", "rdb_table" ) %in% names( cc ) ) ) {
    stop( "`cc` needs `xpath` and `rdb_table` columns." )
  }

  cc <- unique( cc[ !is.na( cc$xpath ) & !is.na( cc$rdb_table ), c( "xpath", "rdb_table" ) ] )
  cc$xpath <- as.character( cc$xpath )
  cc$rdb_table <- as.character( cc$rdb_table )

  out <- list()
  missed <- list()

  for ( tn in names( TABLE.HEADERS ) ) {
    # Reproduce build_rdb_table()'s filter EXACTLY -- including the unanchored
    # grepl. If that call changes, change this one with it or the audit lies.
    hd <- gsub( "//", "/", TABLE.HEADERS[[ tn ]] )
    rx <- paste0( hd, collapse = "|" )

    hit <- grepl( rx, cc$xpath, fixed = FALSE )
    if ( !any( hit ) ) next

    owner <- cc$rdb_table[ hit ]
    foreign <- owner != tn
    if ( any( foreign ) ) {
      fx <- cc$xpath[ hit ][ foreign ]
      fo <- owner[ foreign ]
      for ( other in unique( fo ) ) {
        out[[ length( out ) + 1L ]] <- data.frame(
          table_name    = tn,
          steals_from   = other,
          n_xpaths      = sum( fo == other ),
          example_xpath = fx[ fo == other ][ 1 ],
          stringsAsFactors = FALSE )
      }
    }

    # Opposite failure: an xpath the concordance assigns to this table that the
    # header does not match at all, so the column never appears in the output.
    own_rows <- cc$rdb_table == tn
    unmatched <- cc$xpath[ own_rows & !grepl( rx, cc$xpath ) ]
    if ( length( unmatched ) ) {
      missed[[ length( missed ) + 1L ]] <- data.frame(
        table_name = tn, n_xpaths = length( unmatched ),
        example_xpath = unmatched[ 1 ], stringsAsFactors = FALSE )
    }
  }

  res <- if ( length( out ) ) do.call( rbind, out ) else
    data.frame( table_name = character(), steals_from = character(),
                n_xpaths = integer(), example_xpath = character(),
                stringsAsFactors = FALSE )
  res <- res[ order( -res$n_xpaths ), , drop = FALSE ]
  attr( res, "unmatched" ) <- if ( length( missed ) ) do.call( rbind, missed ) else NULL

  if ( verbose ) {
    if ( nrow( res ) == 0 ) {
      message( "audit_table_headers(): no cross-table misfires." )
    } else {
      message( sprintf(
        "audit_table_headers(): %d misfire(s) across %d table(s); %d xpath(s) captured by the wrong table.",
        nrow( res ), length( unique( res$table_name ) ), sum( res$n_xpaths ) ) )
    }
    um <- attr( res, "unmatched" )
    if ( !is.null( um ) ) {
      message( sprintf(
        "  also %d table(s) with %d xpath(s) their own header does NOT match.",
        nrow( um ), sum( um$n_xpaths ) ) )
    }
  }
  res
}
