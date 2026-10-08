##########
##########  PATCH INDEX: IRS FILINGS MISSING FROM THE GTDC INDEX
##########
##
##  The GTDC index can skip whole IRS batches (EF2-18). This file builds a
##  "patch": the IRS-indexed filings that the GTDC index lacks, with their XML
##  taken from the IRS bulk-download zips and re-hosted on the NCCS bucket at
##
##    https://nccs-efile.s3.us-east-1.amazonaws.com/xml2/<build>_patch/<OBJECT_ID>_public.xml
##
##  Workflow:
##
##    irs   <- get_irs_index( 2019:2026 )
##    gt    <- get_current_index_full()
##    miss  <- diff_irs_gt( irs, gt )
##    got   <- fetch_irs_xml( miss, dest = "v2_3_patch" )
##    patch <- build_patch_index( miss, got, dest = "v2_3_patch", build = "v2_3" )
##    upload_patch( "v2_3_patch", build = "v2_3" )        # needs write credentials
##    index <- combine_index( gt, patch )                 # feed to update_db()
##


#' @title Base URL of the IRS e-file XML downloads
#' @return Character URL with a trailing slash.
#' @keywords internal
irs_xml_base <- function() {
  "https://apps.irs.gov/pub/epostcard/990/xml/"
}


#' @title Read IRS e-file index files
#'
#' @description Reads the IRS `index_<year>.csv` files from the Form 990
#'  series downloads and keeps the requested return types.
#'
#' @details Every column is read as character, so `OBJECT_ID` and `EIN` keep
#'  their digits. Index years before 2024 have no `XML_BATCH_ID` column; it is
#'  added as `NA`. `INDEX_YEAR` records which file each row came from.
#'
#' @param years Integer vector of IRS index years (the year the IRS processed
#'  the filing, not the tax year).
#' @param form_types Return types to keep (`RETURN_TYPE`). Default keeps 990,
#'  990EZ and 990PF; use `NULL` to keep all.
#' @param timeout Seconds allowed for each download.
#' @return A `data.table` of index rows.
#' @examples
#' \dontrun{
#' irs <- get_irs_index( 2024:2026 )
#' }
#' @export
get_irs_index <- function( years, form_types = c("990","990EZ","990PF"), timeout = 600 ) {
  old <- options( timeout = max( timeout, getOption("timeout") ) )
  on.exit( options(old), add = TRUE )
  read_one <- function( y ) {
    url <- paste0( irs_xml_base(), y, "/index_", y, ".csv" )
    message( "Reading ", url )
    dt <- data.table::fread( url, colClasses = "character", showProgress = FALSE )
    if ( ! "XML_BATCH_ID" %in% names(dt) ) { dt[ , XML_BATCH_ID := NA_character_ ] }
    dt[ , INDEX_YEAR := as.character(y) ]
    dt
  }
  dt <- data.table::rbindlist( lapply( years, read_one ), use.names = TRUE, fill = TRUE )
  if ( ! is.null(form_types) ) { dt <- dt[ RETURN_TYPE %in% form_types ] }
  dt <- dt[ ! duplicated(OBJECT_ID) ]
  return(dt)
}


#' @title List the IRS bulk-download zip files
#'
#' @description Reads the IRS "Form 990 series downloads" page and returns the
#'  links to the XML zip files.
#'
#' @details A batch can span several zips: the IRS index labels both halves of
#'  May 2026 `2026_TEOS_XML_05A`, but the second half is in
#'  `2026_TEOS_XML_05B.zip`. Use [match_batch_zips()] to map batches to zips.
#'
#' @param years Optional integer vector; keep only zips for these index years.
#' @param page URL of the downloads page.
#' @return A `data.frame` with columns `year`, `zip` (file name without
#'  `.zip`), and `url`.
#' @examples
#' \dontrun{
#' get_irs_zip_urls( 2025:2026 )
#' }
#' @export
get_irs_zip_urls <- function( years = NULL,
                              page = "https://www.irs.gov/charities-non-profits/form-990-series-downloads" ) {
  resp <- httr::GET( page, httr::user_agent("Mozilla/5.0 (ef2 R package)"), httr::timeout(60) )
  httr::stop_for_status( resp )
  html <- httr::content( resp, as = "text", encoding = "UTF-8" )
  pat  <- "https://apps\\.irs\\.gov/pub/epostcard/990/xml/[0-9]{4}/[A-Za-z0-9_]+\\.zip"
  urls <- unique( regmatches( html, gregexpr( pat, html ) )[[1]] )
  zips <- data.frame(
    year = as.integer( sub( ".*/xml/([0-9]{4})/.*", "\\1", urls ) ),
    zip  = sub( "\\.zip$", "", basename(urls) ),
    url  = urls,
    stringsAsFactors = FALSE )
  if ( ! is.null(years) ) { zips <- zips[ zips$year %in% years, ] }
  zips[ order( zips$zip ), ]
}


#' @title Match IRS batch IDs to the zip files that hold them
#'
#' @description A batch `YYYY_TEOS_XML_MMx` can be split across zips that share
#'  the `YYYY_TEOS_XML_MM` stem (e.g. `05A` and `05B`). Matching is on that stem
#'  and ignores case (the IRS used `2024_TEOS_XML_04a`).
#'
#' @param batches Character vector of `XML_BATCH_ID` values.
#' @param zips Output of [get_irs_zip_urls()].
#' @return The rows of `zips` that may contain the batches.
#' @export
match_batch_zips <- function( batches, zips ) {
  stem <- function(x) toupper( substr( x, 1, 16 ) )
  zips[ stem(zips$zip) %in% stem( stats::na.omit(batches) ), , drop = FALSE ]
}


#' @title Find IRS-indexed filings missing from the GTDC index
#'
#' @description Compares object IDs and returns the IRS index rows whose filing
#'  is not in the GTDC index.
#'
#' @param irs Output of [get_irs_index()].
#' @param gt A GTDC index, e.g. from [get_current_index_full()]. Needs an
#'  `ObjectId` column, or a `URL` column the ID can be read from.
#' @return The subset of `irs`. A summary by `XML_BATCH_ID` is printed.
#' @export
diff_irs_gt <- function( irs, gt ) {
  gt_ids <- if ( "ObjectId" %in% names(gt) ) {
    as.character( gt[["ObjectId"]] )
  } else {
    sub( "^OID-", "", get_object_id2( gt[["URL"]] ) )
  }
  miss <- irs[ ! OBJECT_ID %in% gt_ids ]
  tab <- miss[ , .N, by = .( XML_BATCH_ID, RETURN_TYPE ) ]
  data.table::setorder( tab, XML_BATCH_ID, RETURN_TYPE )
  cat( knitr::kable( tab ), sep = "\n" )
  message( format( nrow(miss), big.mark = "," ), " IRS filings are missing from the GTDC index." )
  return( miss )
}


#' @title Extract missing filings from the IRS zip files
#'
#' @description For each zip that may hold the missing filings, downloads it,
#'  extracts only the wanted `<OBJECT_ID>_public.xml` files into `dest`, and
#'  deletes the zip.
#'
#' @details Files already in `dest` are not fetched again, so an interrupted
#'  run can be restarted. Rows with no `XML_BATCH_ID` (index years before 2024)
#'  cannot be mapped to a zip and are reported, not fetched.
#'
#' @param miss Output of [diff_irs_gt()].
#' @param dest Local folder for the XML files.
#' @param zips Output of [get_irs_zip_urls()]; read from the IRS page if `NULL`.
#' @param zip_dir Folder for the temporary zip downloads.
#' @param keep_zips Keep the downloaded zips (default `FALSE`).
#' @return A `data.frame` with `OBJECT_ID`, `ZIP_FILE` and `FILE` for every
#'  file now in `dest`.
#' @export
fetch_irs_xml <- function( miss, dest, zips = NULL, zip_dir = tempdir(), keep_zips = FALSE ) {
  dir.create( dest, showWarnings = FALSE, recursive = TRUE )
  if ( is.null(zips) ) { zips <- get_irs_zip_urls() }

  no_batch <- miss[ is.na(XML_BATCH_ID) ]
  if ( nrow(no_batch) > 0 ) {
    message( nrow(no_batch), " missing filings have no XML_BATCH_ID and are not fetched: ",
             paste( utils::head( no_batch$OBJECT_ID, 5 ), collapse = ", " ),
             if ( nrow(no_batch) > 5 ) ", ..." )
  }

  stem   <- function(x) toupper( substr( x, 1, 16 ) )
  rows   <- miss[ ! is.na(XML_BATCH_ID) ]
  wanted <- data.frame( FILE = paste0( rows$OBJECT_ID, "_public.xml" ),
                        STEM = stem( rows$XML_BATCH_ID ), stringsAsFactors = FALSE )
  todo   <- match_batch_zips( unique( miss$XML_BATCH_ID ), zips )

  # The manifest records which zip each extracted file came from, so a
  # restarted run keeps the files an earlier run extracted.
  manifest_file <- file.path( dest, "FETCH-MANIFEST.csv" )
  manifest <- if ( file.exists(manifest_file) ) {
    utils::read.csv( manifest_file, colClasses = "character" )
  } else {
    data.frame( FILE = character(0), ZIP_FILE = character(0) )
  }
  manifest <- manifest[ manifest$FILE %in% list.files(dest), , drop = FALSE ]
  # Drop (and delete) files an earlier run extracted badly, so they are fetched
  # again rather than published.
  valid <- vapply( file.path( dest, manifest$FILE ), is_xml_file, logical(1) )
  if ( any( ! valid ) ) {
    message( sum( ! valid ), " previously extracted files are not valid XML; re-fetching them." )
    unlink( file.path( dest, manifest$FILE[ ! valid ] ) )
    manifest <- manifest[ valid, , drop = FALSE ]
    utils::write.csv( manifest, manifest_file, row.names = FALSE )
  }
  found <- list( manifest )

  for ( i in seq_len( nrow(todo) ) ) {
    # Search each zip only for its own batch's files: a long pattern list makes
    # stream_unzip() scale with (entries x patterns).
    done <- unlist( lapply( found, `[[`, "FILE" ) )
    need <- setdiff( wanted$FILE[ wanted$STEM == stem( todo$zip[i] ) ], done )
    if ( length(need) == 0 ) { next }
    zf <- file.path( zip_dir, paste0( todo$zip[i], ".zip" ) )
    if ( ! file.exists(zf) ) {
      message( "Downloading ", todo$url[i] )
      curl::curl_download( todo$url[i], zf, quiet = TRUE )
    }
    ex  <- extract_zip_files( zf, need, dest )
    hit <- ex$files
    msg <- paste0( length(hit), " of ", length(need), " wanted files extracted (",
                   if ( nzchar(ex$method) ) ex$method else "none", ")" )
    if ( length(hit) > 0 ) {
      new <- data.frame( FILE = basename(hit), ZIP_FILE = todo$zip[i], stringsAsFactors = FALSE )
      found[[ todo$zip[i] ]] <- new
      utils::write.table( new, manifest_file, sep = ",", row.names = FALSE,
                          col.names = ! file.exists(manifest_file),
                          append = file.exists(manifest_file) )
    }
    message( todo$zip[i], ": ", msg )
    if ( ! keep_zips ) { unlink(zf) }
  }

  got <- do.call( rbind, found )
  got <- got[ got$FILE %in% wanted$FILE & ! duplicated(got$FILE), , drop = FALSE ]
  got$OBJECT_ID <- sub( "_public\\.xml$", "", got$FILE )
  left <- setdiff( wanted$FILE, got$FILE )
  if ( length(left) > 0 ) {
    message( length(left), " wanted files were not found in any matching zip." )
  }
  return( got[ , c("OBJECT_ID","ZIP_FILE","FILE") ] )
}


#' @title Is a file an XML document (and not blank or zero-filled)?
#' @param path Path to a file.
#' @return `TRUE` if the first non-BOM, non-whitespace byte is `<`.
#' @keywords internal
is_xml_file <- function( path ) {
  if ( ! file.exists(path) ) { return(FALSE) }
  b <- readBin( path, "raw", 256 )
  if ( length(b) >= 3 && identical( b[1:3], as.raw( c(0xef,0xbb,0xbf) ) ) ) { b <- b[-(1:3)] }
  b <- b[ ! b %in% as.raw( c(0x20,0x09,0x0a,0x0d) ) ]
  length(b) > 0 && b[1] == as.raw(0x3c)
}


#' @title Extract named files from an IRS zip, trying several extractors
#'
#' @description IRS zips defeat any single extractor:
#'
#'  * `zip` (miniz) reads ordinary zips. It cannot read the large zip64
#'    archives (e.g. `2024_TEOS_XML_05A.zip`, 156,237 entries), and it cannot
#'    read **Deflate64** (method 9), which `2026_TEOS_XML_05B.zip` uses.
#'  * Info-ZIP `unzip` reads Deflate64. It warns about the zip64 entry count
#'    but extracts correctly.
#'  * `bsdtar` in streaming mode reads damaged-index zips that use ordinary
#'    Deflate. On Deflate64 it **writes zero-filled files without failing**.
#'
#'  So each extractor's output is checked with [is_xml_file()], and files
#'  that fail are passed to the next one. Only valid files reach `dest`.
#'
#' @param zf Path to the zip.
#' @param files File names (no folder) wanted.
#' @param dest Destination folder.
#' @return A list: `files` (the names extracted) and `method` (the
#'  extractors that contributed, joined with `+`).
#' @keywords internal
extract_zip_files <- function( zf, files, dest ) {
  listed <- NULL
  methods <- list(
    zip = function( out ) {
      contents <- zip::zip_list( zf )$filename
      listed <<- basename( contents )
      hit <- contents[ basename(contents) %in% files ]
      if ( length(hit) > 0 ) { zip::unzip( zf, files = hit, exdir = out, junkpaths = TRUE ) }
    },
    unzip  = function( out ) info_unzip( zf, files, out ),
    bsdtar = function( out ) stream_unzip( zf, files, out ) )

  left <- files
  used <- character(0)
  for ( m in names(methods) ) {
    if ( length(left) == 0 ) { break }
    out <- tempfile( "x" ); dir.create( out )
    ok  <- tryCatch( { methods[[m]]( out ); TRUE }, error = function(e) FALSE )
    # When the zip's index could be read, files it does not list are not in
    # it, so there is no point trying the slower extractors for them.
    if ( ! is.null(listed) ) { left <- intersect( left, listed ) }
    if ( ok ) {
      cand <- list.files( out, pattern = "_public\\.xml$", recursive = TRUE, full.names = TRUE )
      cand <- cand[ basename(cand) %in% left ]
      cand <- cand[ vapply( cand, is_xml_file, logical(1) ) ]
      if ( length(cand) > 0 ) {
        file.copy( cand, file.path( dest, basename(cand) ), overwrite = TRUE )
        left <- setdiff( left, basename(cand) )
        used <- c( used, m )
      }
    }
    unlink( out, recursive = TRUE )
  }
  got <- setdiff( files, left )
  got <- got[ file.exists( file.path( dest, got ) ) ]
  list( files = got, method = paste( used, collapse = "+" ) )
}


#' @title Extract files with Info-ZIP unzip
#' @description Used by [extract_zip_files()] for Deflate64 zips. Up to 200
#'  names are passed as patterns; above that the whole zip is extracted (into a
#'  temporary folder) and the caller keeps what it needs.
#' @param zf Path to the zip.
#' @param files File names (no folder) wanted.
#' @param out Folder to extract into (flattened).
#' @keywords internal
info_unzip <- function( zf, files, out ) {
  uz <- Sys.which( "unzip" )
  if ( ! nzchar(uz) ) { stop( "Info-ZIP unzip not found on PATH." ) }
  pats <- if ( length(files) <= 200 ) shQuote( paste0( "*", files ) ) else character(0)
  # unzip exits non-zero on the zip64 entry-count warning; output is validated
  # by the caller instead.
  suppressWarnings( system2( uz, c( "-o", "-j", "-qq", shQuote(zf), pats, "-d", shQuote(out) ),
                             stdout = FALSE, stderr = FALSE ) )
  invisible( NULL )
}


#' @title Extract files from a zip whose central directory is damaged
#'
#' @description Last resort in [extract_zip_files()]. Some IRS zips cannot be
#'  opened by index; reading them front to back from the local file headers
#'  works for entries compressed with ordinary Deflate. The zip is piped through
#'  libarchive's `bsdtar` in streaming mode and only the wanted files are
#'  extracted. **On Deflate64 entries bsdtar writes zero-filled files**, which
#'  is why the caller validates the output.
#'
#' @details Needs `bsdtar`. It ships with Windows 10+ as
#'  `%SystemRoot%\System32\tar.exe`, and with macOS as `tar`. GNU tar cannot read
#'  zip files. A large zip takes a few minutes, because it is read in full.
#'
#' @param zf Path to the zip file.
#' @param files File names (no folder) to extract.
#' @param dest Folder to put them in, without the zip's internal folders.
#' @return The base names of the files extracted.
#' @keywords internal
stream_unzip <- function( zf, files, dest ) {
  win <- file.path( Sys.getenv("SystemRoot"), "System32", "tar.exe" )
  cand <- unique( c( if ( file.exists(win) ) win, Sys.which( c("bsdtar","tar") ) ) )
  cand <- cand[ nzchar(cand) ]
  is_bsd <- vapply( cand, function(x) {
    v <- tryCatch( system2( x, "--version", stdout = TRUE, stderr = TRUE ), error = function(e) "" )
    any( grepl( "bsdtar", v ) )
  }, logical(1) )
  if ( ! any(is_bsd) ) { stop( "stream_unzip() needs bsdtar (libarchive); none found." ) }
  tar <- cand[ is_bsd ][1]

  tmp <- tempfile( "unzip" ); dir.create( tmp )
  on.exit( unlink( tmp, recursive = TRUE ), add = TRUE )
  pat <- file.path( tmp, "patterns.txt" )
  writeLines( c( files, paste0( "*/", files ) ), pat )
  out <- file.path( tmp, "out" ); dir.create( out )
  # The zip must arrive through a pipe. Given a seekable file (including
  # system2(stdin = zf)), libarchive reads the damaged central directory and
  # fails.
  windows <- .Platform$OS.type == "windows"
  cmd <- paste( shQuote(tar), "-xf - -T", shQuote(pat), "-C", shQuote(out),
                if ( windows ) "> NUL 2>&1" else "> /dev/null 2>&1" )
  # cmd.exe drops the first and last quote of a line that starts with one.
  if ( windows ) { cmd <- paste0( '"', cmd, '"' ) }
  pc  <- pipe( cmd, open = "wb" )
  fc  <- file( zf, open = "rb" )
  repeat {
    chunk <- readBin( fc, "raw", n = 64 * 1024^2 )
    if ( length(chunk) == 0 ) { break }
    writeBin( chunk, pc )
  }
  close( fc )
  suppressWarnings( close( pc ) )   # bsdtar exits non-zero on the damaged index
  got <- list.files( out, pattern = "_public\\.xml$", recursive = TRUE, full.names = TRUE )
  got <- got[ basename(got) %in% files ]
  file.copy( got, file.path( dest, basename(got) ), overwrite = TRUE )
  return( basename(got) )
}


#' @title Read return-header fields from e-file XML documents
#'
#' @description Reads the fields a build index needs from each file's
#'  `ReturnHeader`, using the same xpaths as [get_keys()] for `TAX_YEAR`.
#'
#' @details `TaxYear` is `TaxYr` (or `TaxYear` in older schemas). When neither
#'  is present it falls back to the year of `TaxPeriodBeginDt`.
#'
#'  A file that cannot be parsed gets a row with `NA` fields and
#'  `READ_ERROR` set to the parser's message, so one bad file does not stop a
#'  run of thousands.
#'
#' @param files Character vector of local XML file paths.
#' @return A `data.table` with `OBJECT_ID`, `TaxYear`, `FormType`, `ReturnTs`,
#'  `TaxPeriodBeginDate`, `TaxPeriodEndDate`, `ReturnVersion`, and
#'  `READ_ERROR`.
#' @export
read_return_headers <- function( files ) {
  one <- function( f ) {
    oid <- sub( "_public\\.xml$", "", basename(f) )
    doc <- tryCatch( xml2::read_xml( f ), error = function(e) conditionMessage(e) )
    if ( is.character(doc) ) {
      return( list( OBJECT_ID = oid, TaxYear = NA_character_, FormType = NA_character_,
                    ReturnTs = NA_character_, TaxPeriodBeginDate = NA_character_,
                    TaxPeriodEndDate = NA_character_, ReturnVersion = NA_character_,
                    READ_ERROR = doc ) )
    }
    xml2::xml_ns_strip( doc )
    get <- function( xp ) {
      node <- xml2::xml_find_first( doc, xp )
      if ( inherits( node, "xml_missing" ) ) NA_character_ else xml2::xml_text( node )
    }
    begin <- get( "/Return/ReturnHeader/TaxPeriodBeginDt|/Return/ReturnHeader/TaxPeriodBeginDate" )
    ty    <- get( "/Return/ReturnHeader/TaxYr|/Return/ReturnHeader/TaxYear" )
    if ( is.na(ty) && ! is.na(begin) ) { ty <- substr( begin, 1, 4 ) }
    list(
      OBJECT_ID          = oid,
      TaxYear            = ty,
      FormType           = get( "/Return/ReturnHeader/ReturnTypeCd|/Return/ReturnHeader/ReturnType" ),
      ReturnTs           = get( "/Return/ReturnHeader/ReturnTs|/Return/ReturnHeader/Timestamp" ),
      TaxPeriodBeginDate = begin,
      TaxPeriodEndDate   = get( "/Return/ReturnHeader/TaxPeriodEndDt|/Return/ReturnHeader/TaxPeriodEndDate" ),
      ReturnVersion      = xml2::xml_attr( xml2::xml_root(doc), "returnVersion" ),
      READ_ERROR         = NA_character_ )
  }
  out <- data.table::rbindlist( lapply( files, one ) )
  bad <- sum( ! is.na( out$READ_ERROR ) )
  if ( bad > 0 ) { message( bad, " file(s) could not be parsed; see READ_ERROR." ) }
  out
}


#' @title Patch URL for a filing
#' @param object_id Character object IDs (no `OID-` prefix).
#' @param build Build name, e.g. `"v2_3"`; the folder is `xml2/<build>_patch/`.
#' @return Character URLs.
#' @export
patch_url <- function( object_id, build ) {
  paste0( "https://nccs-efile.s3.us-east-1.amazonaws.com/xml2/", build, "_patch/",
          object_id, "_public.xml" )
}


#' @title Build the patch index
#'
#' @description Joins the IRS index rows of the missing filings to what
#'  [fetch_irs_xml()] extracted and to each file's return header, and writes
#'  the result to `dest`.
#'
#' @details The output has the IRS index columns, plus the columns a GTDC index
#'  has that [update_db()] and [combine_index()] use: `ObjectId`, `URL`,
#'  `TaxYear`, `FormType`. It also has `ZipFile`, `PATCH_BUILD`, and
#'  `PATCH_CREATED`. Only filings whose XML was extracted are included.
#'
#' @param miss Output of [diff_irs_gt()].
#' @param got Output of [fetch_irs_xml()].
#' @param dest Folder holding the extracted XML files; the index CSV is
#'  written there too.
#' @param build Build name, e.g. `"v2_3"`.
#' @return The patch index as a `data.table`, invisibly. Written to
#'  `<dest>/PATCH-INDEX-<build>-<YYYY-MM-DD>.csv`.
#' @export
build_patch_index <- function( miss, got, dest, build ) {
  hdr <- read_return_headers( file.path( dest, got$FILE ) )
  px  <- merge( data.table::as.data.table(miss), data.table::as.data.table(got),
                by = "OBJECT_ID" )
  px  <- merge( px, data.table::as.data.table(hdr), by = "OBJECT_ID", all.x = TRUE )
  px[ , `:=`( ObjectId = OBJECT_ID,
              URL = patch_url( OBJECT_ID, build ),
              ZipFile = ZIP_FILE,
              PATCH_BUILD = build,
              PATCH_CREATED = as.character( Sys.Date() ) ) ]
  px[ , c("ZIP_FILE","FILE") := NULL ]
  fn <- file.path( dest, paste0( "PATCH-INDEX-", build, "-", Sys.Date(), ".csv" ) )
  data.table::fwrite( px, fn )
  message( "Wrote ", format( nrow(px), big.mark = "," ), " rows to ", fn )
  cat( knitr::kable( table( px$TaxYear, px$FormType ) ), sep = "\n" )
  invisible( px )
}


#' @title Upload patch XML files and index to the NCCS bucket
#'
#' @description Copies every `*_public.xml` and `PATCH-INDEX-*.csv` in `dir` to
#'  `s3://nccs-efile/xml2/<build>_patch/`, skipping files already there.
#'
#' @details Uses [aws.s3::put_object()], which finds credentials with
#'  [aws.signature::locate_credentials()]: environment variables,
#'  `~/.aws/credentials`, or `.Renviron`. The bucket is public, so the uploaded
#'  files are publicly readable.
#'
#' @param dir Local folder from [fetch_irs_xml()] / [build_patch_index()].
#' @param build Build name, e.g. `"v2_3"`.
#' @param bucket S3 bucket (default `"nccs-efile"`).
#' @param dry_run If `TRUE` (default), report what would be uploaded and stop.
#' @param workers Parallel uploads.
#' @return A `data.frame` of files and upload status, invisibly.
#' @export
upload_patch <- function( dir, build, bucket = "nccs-efile", dry_run = TRUE, workers = 8 ) {
  if ( ! requireNamespace( "aws.s3", quietly = TRUE ) ) { stop( "upload_patch() needs the aws.s3 package." ) }
  prefix <- paste0( "xml2/", build, "_patch/" )
  files  <- list.files( dir, pattern = "_public\\.xml$|^PATCH-INDEX-.*\\.csv$" )
  xml    <- grepl( "_public\\.xml$", files )
  bad    <- files[ xml ][ ! vapply( file.path( dir, files[ xml ] ), is_xml_file, logical(1) ) ]
  if ( length(bad) > 0 ) {
    message( length(bad), " file(s) are not valid XML and will not be uploaded, e.g. ", bad[1] )
    files <- setdiff( files, bad )
  }
  have   <- aws.s3::get_bucket_df( bucket, prefix = prefix, max = Inf )$Key
  todo   <- files[ ! paste0( prefix, files ) %in% have ]
  message( length(files), " local files; ", length(todo), " not yet in s3://", bucket, "/", prefix )
  if ( dry_run ) {
    message( "Dry run: nothing uploaded. Set dry_run = FALSE to upload." )
    return( invisible( data.frame( file = todo, uploaded = FALSE ) ) )
  }
  put <- function( f ) {
    type <- if ( grepl( "\\.csv$", f ) ) "text/csv" else "application/xml"
    isTRUE( tryCatch(
      aws.s3::put_object( file = file.path( dir, f ), object = paste0( prefix, f ), bucket = bucket,
                          headers = list( `Content-Type` = type ) ),
      error = function(e) FALSE ) )
  }
  future::plan( future::multisession, workers = workers )
  on.exit( future::plan( future::sequential ), add = TRUE )
  # Upload in chunks so a long run reports progress.
  chunks <- split( todo, ceiling( seq_along(todo) / 5000 ) )
  ok <- logical(0)
  for ( k in seq_along(chunks) ) {
    ok <- c( ok, unlist( furrr::future_map( chunks[[k]], put ) ) )
    message( format( Sys.time(), "%H:%M:%S" ), "  ", length(ok), " / ", length(todo),
             " done; ", sum(!ok), " failed so far" )
  }
  message( sum(ok), " uploaded; ", sum(!ok), " failed." )
  invisible( data.frame( file = todo, uploaded = ok ) )
}


#' @title Combine a GTDC index with a patch index
#'
#' @description Stacks the two indices into one build index with one row per
#'  filing. Where a filing is in both, the GTDC row is kept, so once GTDC
#'  catches up the patch row drops out.
#'
#' @param gt A GTDC index (e.g. [get_current_index_full()] or the batch index).
#' @param patch Output of [build_patch_index()], or the patch index CSV read
#'  back with all columns as character.
#' @param cols Columns to keep; must exist in both inputs.
#' @return A `data.table` with `cols` plus `SOURCE` (`"GTDC"` or `"PATCH"`).
#' @export
combine_index <- function( gt, patch, cols = c("ObjectId","URL","TaxYear","FormType") ) {
  a <- data.table::as.data.table( gt )[ , ..cols ]
  b <- data.table::as.data.table( patch )[ , ..cols ]
  a[ , names(a) := lapply( .SD, as.character ) ]
  b[ , names(b) := lapply( .SD, as.character ) ]
  a[ , SOURCE := "GTDC" ]
  b[ , SOURCE := "PATCH" ]
  out <- data.table::rbindlist( list( a, b ) )
  out <- out[ ! duplicated( ObjectId ) ]
  message( "Combined index: ", format( sum( out$SOURCE == "GTDC" ), big.mark = "," ), " GTDC + ",
           format( sum( out$SOURCE == "PATCH" ), big.mark = "," ), " patch rows." )
  return( out )
}
