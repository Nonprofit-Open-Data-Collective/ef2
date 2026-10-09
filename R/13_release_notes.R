##########
##########  RELEASE NOTES: WHAT CHANGED BETWEEN TWO PUBLISHED RELEASES
##########
##
##    cmp <- compare_releases( "public/efile_v2_3/", "public/efile_v3_1/",
##                             old_concordance = cc_old, new_concordance = cc_new )
##    write_release_notes( cmp, "RELEASE-NOTES-EFILE_V3_1.md", title = "efile_v3_1" )
##
##  Everything is read from Parquet metadata and schemas except the filing
##  counts, which scan the header tables (`filings = FALSE` skips them).
##


#' @title List the Parquet tables of a release
#'
#' @description Lists `<TABLE>-<YEAR>.parquet` files in a local folder or an
#'  S3 prefix of the public NCCS bucket.
#'
#' @param path A local folder, an `s3://bucket/prefix/` URI, or a bare prefix
#'  of the NCCS bucket such as `"public/efile_v3_1/"`. S3 prefixes are listed
#'  anonymously over HTTPS.
#' @return A `data.table` with `table`, `year` and `file` (a path or HTTPS URL
#'  DuckDB can read).
#' @keywords internal
release_files <- function( path ) {
  if ( dir.exists( path ) ) {
    f <- list.files( path, pattern = "-[0-9]{4}[.]parquet$", full.names = TRUE )
    f <- normalizePath( f, winslash = "/" )
  } else {
    bucket <- "nccs-efile"; prefix <- path
    if ( grepl( "^s3://", path ) ) {
      bucket <- sub( "^s3://([^/]+)/.*$", "\\1", path )
      prefix <- sub( "^s3://[^/]+/", "", path )
    }
    base <- sprintf( "https://%s.s3.us-east-1.amazonaws.com/", bucket )
    keys <- character(0); token <- NULL
    repeat {
      resp <- httr::GET( base, query = list( `list-type` = 2, prefix = prefix, `continuation-token` = token ),
                         httr::timeout(60) )
      httr::stop_for_status( resp )
      x <- xml2::read_xml( httr::content( resp, as = "text", encoding = "UTF-8" ) )
      xml2::xml_ns_strip( x )
      keys <- c( keys, xml2::xml_text( xml2::xml_find_all( x, "//Contents/Key" ) ) )
      if ( !identical( xml2::xml_text( xml2::xml_find_first( x, "//IsTruncated" ) ), "true" ) ) break
      token <- xml2::xml_text( xml2::xml_find_first( x, "//NextContinuationToken" ) )
    }
    keys <- keys[ grepl( "-[0-9]{4}[.]parquet$", keys ) ]
    f <- paste0( base, keys )
  }
  if ( !length(f) ) stop( "no <TABLE>-<YEAR>.parquet files found under ", path )
  data.table::data.table(
    table = sub( "-[0-9]{4}[.]parquet$", "", basename(f) ),
    year  = as.integer( sub( ".*-([0-9]{4})[.]parquet$", "\\1", basename(f) ) ),
    file  = f )
}


#' @title Collapse years into ranges
#' @param y Integer years.
#' @return A string such as `"2009-2011, 2013"`.
#' @examples
#' condense_years( c( 2009, 2010, 2011, 2013 ) )
#' @export
condense_years <- function( y ) {
  y <- sort( unique( as.integer(y) ) )
  if ( !length(y) ) return( "" )
  grp <- cumsum( c( 1, diff(y) != 1 ) )
  paste( vapply( split( y, grp ), function(r)
    if ( length(r) == 1 ) as.character(r) else paste0( r[1], "-", r[length(r)] ), "" ), collapse = ", " )
}


#' @title Compare two releases of the published tables
#'
#' @description Reports what changed between two releases: tables added and
#'  dropped, rows and columns per table and year, columns added and removed,
#'  filings per tax year, and (given both concordances) label changes. Use
#'  [write_release_notes()] to render the result.
#'
#' @details Row and column counts come from Parquet metadata, so they are cheap
#'  even over S3. Filing counts scan each year's header table
#'  (`F9-P00-T00-HEADER`) and are skipped with `filings = FALSE`.
#'
#'  The comparison reports *what* changed, not why. Context such as which
#'  filings were added and where they came from belongs in the `notes`
#'  argument of [write_release_notes()].
#'
#' @param old,new Releases: local folders, `s3://` URIs, or bare prefixes of
#'  the NCCS bucket (e.g. `"public/efile_v2_3/"`).
#' @param old_concordance,new_concordance Optional data frames with `xpath`,
#'  `variable_name` and `rdb_table` (and optionally `multi_value`), e.g. from
#'  `concordance990::concordance("v2", form = "F990")`. Both are needed for the
#'  `labels` component.
#' @param filings Count filings per year and return type from the header tables.
#' @param labels Display names for the two releases (default: the paths).
#' @return A list of class `release_comparison` with `meta`, `tables`, `dims`,
#'  `columns`, `filings` and `labels`.
#' @export
compare_releases <- function( old, new, old_concordance = NULL, new_concordance = NULL,
                              filings = TRUE, labels = c( old, new ) ) {
  con <- DBI::dbConnect( duckdb::duckdb(), dbdir = ":memory:" )
  on.exit( DBI::dbDisconnect( con, shutdown = TRUE ), add = TRUE )
  fo <- release_files( old ); fn <- release_files( new )
  if ( any( grepl( "^https://", c( fo$file, fn$file ) ) ) ) {
    DBI::dbExecute( con, "INSTALL httpfs" ); DBI::dbExecute( con, "LOAD httpfs" )
  }
  lst <- function( f ) paste0( "[", paste0( "'", f, "'", collapse = "," ), "]" )

  # Rows (metadata) and leaf columns (schema), one query each per release.
  meta <- function( f, ver ) {
    rows <- data.table::as.data.table( DBI::dbGetQuery( con, sprintf(
      "SELECT file_name, sum(num_rows) AS rows FROM (SELECT DISTINCT file_name, row_group_id, row_group_num_rows AS num_rows
         FROM parquet_metadata(%s)) GROUP BY 1", lst( f$file ) ) ) )
    cols <- data.table::as.data.table( DBI::dbGetQuery( con, sprintf(
      "SELECT file_name, name FROM parquet_schema(%s) WHERE num_children IS NULL OR num_children = 0", lst( f$file ) ) ) )
    norm <- function(x) gsub( "\\\\", "/", x )
    rows[ , file := norm( file_name ) ]; cols[ , file := norm( file_name ) ]
    d <- merge( f, rows[ , list( file, rows ) ], by = "file" )
    d[ , ncol := cols[ , .N, by = file ][ match( d$file, file ), N ] ]
    d[ , version := ver ]
    list( dims = d, cols = merge( f[ , list( file, table, year ) ], cols[ , list( file, column = name ) ], by = "file" )[ , version := ver ] )
  }
  mo <- meta( fo, "old" ); mn <- meta( fn, "new" )

  dims <- data.table::dcast( data.table::rbindlist( list( mo$dims, mn$dims ) ), table + year ~ version,
                             value.var = c( "rows", "ncol" ) )
  for ( v in c( "rows_old", "rows_new", "ncol_old", "ncol_new" ) ) if ( !v %in% names(dims) ) dims[ , (v) := NA_real_ ]
  dims[ , `:=`( d_rows = rows_new - rows_old, d_cols = ncol_new - ncol_old ) ]

  tabs <- function( d ) d[ , list( years = condense_years( year ), n_years = .N ), by = table ]
  t_old <- tabs( fo ); t_new <- tabs( fn )
  tables <- list( added   = t_new[ !table %in% t_old$table ],
                  dropped = t_old[ !table %in% t_new$table ],
                  per_year = merge( fo[ , list( old = .N ), by = year ], fn[ , list( new = .N ), by = year ], by = "year", all = TRUE ) )

  # Columns added or removed, for tables present in both releases, by year.
  both <- intersect( t_old$table, t_new$table )
  co <- unique( mo$cols[ table %in% both, list( table, year, column ) ] )
  cn <- unique( mn$cols[ table %in% both, list( table, year, column ) ] )
  yrs <- intersect( fo$year, fn$year )
  added   <- data.table::fsetdiff( cn[ year %in% yrs ], co[ year %in% yrs ] )
  removed <- data.table::fsetdiff( co[ year %in% yrs ], cn[ year %in% yrs ] )
  # Only year-pairs where both releases have the table count as a change.
  have <- merge( fo[ , list( table, year ) ], fn[ , list( table, year ) ], by = c( "table", "year" ) )
  added   <- merge( added, have, by = c( "table", "year" ) )
  removed <- merge( removed, have, by = c( "table", "year" ) )
  columns <- data.table::rbindlist( list(
    added[ , list( change = "added", years = condense_years( year ) ), by = list( table, column ) ],
    removed[ , list( change = "removed", years = condense_years( year ) ), by = list( table, column ) ] ) )
  if ( nrow( columns ) ) data.table::setorder( columns, table, change, column )

  fil <- NULL
  if ( filings ) {
    hdr <- function( f, ver ) {
      h <- f[ table == "F9-P00-T00-HEADER" ]
      if ( !nrow(h) ) return( NULL )
      data.table::as.data.table( DBI::dbGetQuery( con, sprintf(
        "SELECT CAST(regexp_extract(filename, '-([0-9]{4})[.]parquet$', 1) AS INTEGER) AS year,
                coalesce(RETURN_TYPE, '(blank)') AS return_type, count(*) AS filings
           FROM read_parquet(%s, filename = true, union_by_name = true) GROUP BY ALL", lst( h$file ) ) ) )[ , version := ver ]
    }
    fl <- data.table::rbindlist( list( hdr( fo, "old" ), hdr( fn, "new" ) ) )
    if ( nrow( fl ) ) {
      fil <- data.table::dcast( fl, year + return_type ~ version, value.var = "filings", fill = 0 )
      for ( v in c( "old", "new" ) ) if ( !v %in% names(fil) ) fil[ , (v) := 0 ]
      fil[ , change := new - old ]
      data.table::setorder( fil, year, return_type )
    }
  }

  lab <- NULL
  if ( !is.null( old_concordance ) && !is.null( new_concordance ) ) {
    keep <- function( cc ) {
      cc <- data.table::as.data.table( cc )
      cols <- intersect( c( "xpath", "variable_name", "rdb_table", "multi_value" ), names(cc) )
      unique( cc[ , ..cols ][ , lapply( .SD, as.character ) ] )
    }
    o <- keep( old_concordance ); n <- keep( new_concordance )
    m <- merge( o, n, by = "xpath", all = TRUE, suffixes = c( "_old", "_new" ) )
    has_mv <- all( c( "multi_value_old", "multi_value_new" ) %in% names(m) )
    lab <- list(
      new_xpaths  = m[ is.na( variable_name_old ), list( xpath, variable_name = variable_name_new, rdb_table = rdb_table_new ) ],
      dropped_xpaths = m[ is.na( variable_name_new ), list( xpath, variable_name = variable_name_old, rdb_table = rdb_table_old ) ],
      renamed     = m[ !is.na( variable_name_old ) & !is.na( variable_name_new ) & variable_name_old != variable_name_new,
                       list( xpath, from = variable_name_old, to = variable_name_new, rdb_table = rdb_table_new ) ],
      moved       = m[ !is.na( rdb_table_old ) & !is.na( rdb_table_new ) & rdb_table_old != rdb_table_new,
                       list( xpath, variable_name = variable_name_new, from = rdb_table_old, to = rdb_table_new ) ],
      multi_value = if ( has_mv ) m[ !is.na( multi_value_old ) & !is.na( multi_value_new ) &
                                       toupper( multi_value_old ) != toupper( multi_value_new ),
                                     list( xpath, variable_name = variable_name_new, from = multi_value_old, to = multi_value_new ) ] else NULL )
  }

  structure( list(
    meta = list( old = labels[1], new = labels[2], created = format( Sys.time(), "%Y-%m-%d %H:%M:%S" ),
                 years_old = condense_years( fo$year ), years_new = condense_years( fn$year ) ),
    tables = tables, dims = dims, columns = columns, filings = fil, labels = lab ),
    class = "release_comparison" )
}


#' @title Write release notes from a release comparison
#'
#' @description Renders a [compare_releases()] result as Markdown: a summary,
#'  filings by tax year, tables added and dropped, column changes grouped by
#'  table, row-count changes, and concordance changes.
#'
#' @param cmp A `release_comparison`.
#' @param file Output `.md` path; `NULL` returns the text only.
#' @param title Release name for the heading.
#' @param notes Optional character vector of hand-written context, placed at
#'  the top under "Notes". The comparison reports what changed; why it changed
#'  has to come from the build record.
#' @param max_rows Longest list printed per section; longer lists are summarised.
#' @return The Markdown text, invisibly.
#' @export
write_release_notes <- function( cmp, file = NULL, title = cmp$meta$new, notes = NULL, max_rows = 60 ) {
  stopifnot( inherits( cmp, "release_comparison" ) )
  fmt <- function(x) format( x, big.mark = ",", scientific = FALSE, trim = TRUE )
  sgn <- function(x) ifelse( is.na(x), "", ifelse( x > 0, paste0( "+", fmt(x) ), fmt(x) ) )
  md_table <- function( d, header ) {
    if ( is.null(d) || !nrow(d) ) return( "_None._" )
    d <- as.data.frame( d )
    shown <- utils::head( d, max_rows )
    shown[] <- lapply( shown, as.character )   # apply() would pad numbers to a common width
    rows <- apply( shown, 1, function(r) paste0( "| ", paste( r, collapse = " | " ), " |" ) )
    c( paste0( "| ", paste( header, collapse = " | " ), " |" ),
       paste0( "|", paste( rep( "---", length(header) ), collapse = "|" ), "|" ), rows,
       if ( nrow(d) > max_rows ) sprintf( "\n_... and %s more._", fmt( nrow(d) - max_rows ) ) )
  }
  tb <- cmp$tables; dm <- cmp$dims; cl <- cmp$columns; fl <- cmp$filings; lb <- cmp$labels

  out <- c( sprintf( "# Release notes: %s", title ), "",
            sprintf( "_Changes from `%s` to `%s`. Generated by `ef2::write_release_notes()` on %s._",
                     cmp$meta$old, cmp$meta$new, substr( cmp$meta$created, 1, 10 ) ), "" )
  if ( length( notes ) ) out <- c( out, "## Notes", "", notes, "" )

  both <- dm[ !is.na( rows_old ) & !is.na( rows_new ) ]
  sum_lines <- c(
    sprintf( "- **Tax years:** %s (previously %s).", cmp$meta$years_new, cmp$meta$years_old ),
    sprintf( "- **Tables:** %s added, %s dropped.", fmt( nrow( tb$added ) ), fmt( nrow( tb$dropped ) ) ),
    sprintf( "- **Table-years in both releases:** %s; row counts changed in %s, column counts in %s; rows fell in %s.",
             fmt( nrow( both ) ), fmt( both[ d_rows != 0, .N ] ), fmt( both[ d_cols != 0, .N ] ), fmt( both[ d_rows < 0, .N ] ) ),
    sprintf( "- **Columns:** %s added and %s removed, across %s tables.",
             fmt( cl[ change == "added", .N ] ), fmt( cl[ change == "removed", .N ] ), fmt( data.table::uniqueN( cl$table ) ) ) )
  if ( !is.null( fl ) ) sum_lines <- c( sum_lines, sprintf( "- **Filings:** %s, previously %s (%s).",
                                                            fmt( sum( fl$new ) ), fmt( sum( fl$old ) ), sgn( sum( fl$new ) - sum( fl$old ) ) ) )
  if ( !is.null( lb ) ) sum_lines <- c( sum_lines, sprintf(
    "- **Concordance:** %s xpaths newly mapped, %s dropped, %s moved between tables, %s variables renamed%s.",
    fmt( nrow( lb$new_xpaths ) ), fmt( nrow( lb$dropped_xpaths ) ), fmt( nrow( lb$moved ) ), fmt( nrow( lb$renamed ) ),
    if ( !is.null( lb$multi_value ) ) sprintf( ", %s `multi_value` changes", fmt( nrow( lb$multi_value ) ) ) else "" ) )
  out <- c( out, "## Summary", "", sum_lines, "" )

  if ( !is.null( fl ) ) {
    fy <- fl[ , list( old = sum(old), new = sum(new) ), by = year ][ , change := new - old ]
    out <- c( out, "## Filings by tax year", "",
              md_table( fy[ , list( year, fmt(old), fmt(new), sgn(change) ) ], c( "Tax year", cmp$meta$old, cmp$meta$new, "Change" ) ), "",
              "By return type:", "",
              md_table( fl[ old != new, list( year, return_type, fmt(old), fmt(new), sgn(change) ) ],
                        c( "Tax year", "Return type", cmp$meta$old, cmp$meta$new, "Change" ) ), "" )
  }

  out <- c( out, "## Tables added and dropped", "",
            "Added:", "", md_table( tb$added[ , list( table, years ) ], c( "Table", "Years" ) ), "",
            "Dropped:", "", md_table( tb$dropped[ , list( table, years ) ], c( "Table", "Years" ) ), "" )

  out <- c( out, "## Column changes", "",
            "Columns added or removed in tables present in both releases, with the tax years affected.", "",
            md_table( cl[ , list( table, change, paste0( "`", column, "`" ), years ) ], c( "Table", "Change", "Column", "Years" ) ), "" )

  rc <- both[ d_rows != 0, list( years = condense_years( year ), rows_old = sum( rows_old ), rows_new = sum( rows_new ) ), by = table ][
    , change := rows_new - rows_old ][ order( -abs( change ) ) ]
  out <- c( out, "## Row-count changes", "",
            "Tables whose row counts changed, summed over the years that changed.", "",
            md_table( rc[ , list( table, years, fmt(rows_old), fmt(rows_new), sgn(change) ) ],
                      c( "Table", "Years", cmp$meta$old, cmp$meta$new, "Change" ) ), "" )

  if ( !is.null( lb ) ) {
    mv <- lb$moved[ , .N, by = list( from, to ) ][ order( -N ) ]
    nx <- lb$new_xpaths[ , .N, by = rdb_table ][ order( -N ) ]
    out <- c( out, "## Concordance changes", "",
              "Xpaths moved between tables:", "", md_table( mv[ , list( from, to, N ) ], c( "From", "To", "Xpaths" ) ), "",
              "Newly mapped xpaths, by table:", "", md_table( nx[ , list( ifelse( rdb_table == "", "(no table)", rdb_table ), N ) ], c( "Table", "Xpaths" ) ), "",
              "Renamed variables:", "", md_table( unique( lb$renamed[ , list( from, to ) ] ), c( "From", "To" ) ), "" )
    if ( !is.null( lb$multi_value ) )
      out <- c( out, "`multi_value` changes:", "",
                md_table( unique( lb$multi_value[ , list( variable_name, data.table::fifelse( from == "", "(blank)", from ),
                                                          data.table::fifelse( to == "", "(blank)", to ) ) ] ), c( "Variable", "From", "To" ) ), "" )
  }

  if ( !is.null( file ) ) writeLines( out, file, useBytes = TRUE )
  invisible( paste( out, collapse = "\n" ) )
}
