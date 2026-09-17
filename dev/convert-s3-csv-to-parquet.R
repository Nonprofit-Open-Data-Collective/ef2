# ---------------------------------------------------------------------------
# Convert the published efile CSV tables to Parquet
#
#   public/efile_v2_1/  1,793 CSV files,  94.2 GB
#   public/efile_v2_2/  1,793 CSV files,  99.8 GB
#   113 table stems x TY2009-2024 in each.
#
# This script is for the tables ALREADY on S3. For tables built from scratch,
# prefer extract_csv_tables( output = "both" ): that writes Parquet straight
# from the DuckDB temp table and never round-trips through text at all.
#
# WHY all_varchar = true IS NOT OPTIONAL
# -------------------------------------
# These CSVs hold digit-strings that are not numbers. Measured on
# F9-P00-T00-HEADER-2023.CSV (527,764 rows x 80 columns):
#
#   F9_00_ORG_ADDR_ZIP        51,318 values with a leading zero
#   F9_00_PRIN_OFF_ADDR_ZIP   28,321
#   ORG_EIN / F9_00_ORG_EIN   22,823
#   F9_00_GROUP_EXEMPT_NUM    10,628 of 23,253  (46%)
#   F9_00_ORG_PHONE            2,299
#
# Reading the same 20,000 rows four ways and comparing every cell against the
# verbatim text: data.table::fread and base::read.csv type ORG_EIN as integer
# and corrupt 7,969 cells each (061721946 -> 61721946). readr and DuckDB detect
# the leading zeros and stay character. pandas.read_csv behaves like fread.
# DuckDB is safe by default here, but all_varchar = true makes it guaranteed
# rather than incidental, and removes any dependence on sample size.
#
# Two further columns would break a boolean cast:
#   F9_00_IRS_RESP_PARTY_INFO_CURR_X  true=251282 1=100993 0=76109 false=57626
#   F9_00_IRS_TRUST_OOB_VERIFIED_X    11=21381   00=17853   ("00", not "0")
#
# WHY nullif(col, '')
# -------------------
# The CSVs write two kinds of blank: a quoted "" (an empty string produced by
# pivot_wider's values_fill) and a bare empty field (a SQL NULL from the KEYS
# right_join). No CSV reader distinguishes them -- DuckDB, readr and read.csv
# all return NA for both -- but Parquet has a real null indicator and would keep
# them apart, so a literal conversion produces a Parquet file that disagrees
# with its own CSV. In the TY2023 header table that is ~12.2 million cells,
# about 29% of the file. Folding '' to NULL reproduces what every CSV reader
# already does, so both formats answer identically.
#
# Set FOLD_EMPTY <- FALSE only if you decide to publish the distinction, and
# document it loudly if you do.
#
# CHECKED, AND NOT A PROBLEM: no value anywhere exceeds 2^53 (no float
# precision risk), no decimal points or exponent notation outside free-text
# fields, no embedded newlines, no leading/trailing whitespace, and quoting is
# well-formed RFC 4180 throughout.
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library( DBI )
  library( duckdb )
})

# ---- settings -------------------------------------------------------------

BUCKET      <- "nccs-efile"
REGION      <- "us-east-1"
PREFIXES    <- c( "public/efile_v2_1/", "public/efile_v2_2/" )

# Where Parquet lands. Set DEST_MODE to "s3" to upload, "local" to stage only.
DEST_MODE   <- "local"
DEST_LOCAL  <- "D:/efile-parquet"
DEST_S3     <- "s3://nccs-efile/parquet/"   # mirrors the CSV prefix layout

STAGE_DIR   <- file.path( tempdir(), "ef2-parquet-stage" )
MANIFEST    <- file.path( DEST_LOCAL, "conversion-manifest.csv" )

FOLD_EMPTY  <- TRUE       # '' -> NULL, so Parquet and CSV agree.  See above.
SORT_KEY    <- "ORG_EIN"  # present in every published table via KEYS
COMPRESSION <- "zstd"
COMP_LEVEL  <- 9L
ROW_GROUP   <- 50000L
MEMORY      <- "12GB"     # the largest input is 1.76 GB; ORDER BY will spill
VERIFY      <- TRUE
KEEP_CSV    <- FALSE      # delete the staged CSV after a verified conversion

# ---- duckdb connection, with the Windows httpfs workaround ----------------

# On Windows the R duckdb package uses windows_amd64_mingw and in-process
# INSTALL httpfs fails even though the extension URL serves fine over curl.
# Fetch and gunzip it once, then LOAD it by path with unsigned extensions
# allowed. See dev/UPSTREAM-ISSUES.md EF2-5.
ensure_httpfs <- function( con, cache = file.path( "~", ".ef2-duckdb-ext" ) ) {

  ok <- tryCatch({
    dbExecute( con, "INSTALL httpfs; LOAD httpfs;" ); TRUE
  }, error = function( e ) FALSE )
  if ( ok ) return( invisible( TRUE ) )

  cache <- path.expand( cache )
  dir.create( cache, showWarnings = FALSE, recursive = TRUE )

  ver  <- dbGetQuery( con, "SELECT version() AS v" )$v
  plat <- dbGetQuery( con, "PRAGMA platform" )[[ 1 ]]
  ext  <- file.path( cache, sprintf( "httpfs-%s-%s.duckdb_extension", ver, plat ) )

  if ( ! file.exists( ext ) ) {
    url <- sprintf( "http://extensions.duckdb.org/%s/%s/httpfs.duckdb_extension.gz",
                    ver, plat )
    gz <- paste0( ext, ".gz" )
    message( "fetching httpfs: ", url )
    utils::download.file( url, gz, mode = "wb", quiet = TRUE )
    R.utils::gunzip( gz, destname = ext, overwrite = TRUE, remove = TRUE )
  }

  dbExecute( con, sprintf( "LOAD '%s';", gsub( "\\\\", "/", ext ) ) )
  invisible( TRUE )
}

open_con <- function() {
  con <- dbConnect( duckdb(), config = list(
    memory_limit                 = MEMORY,
    temp_directory               = file.path( tempdir(), "duckdb-spill" ),
    allow_unsigned_extensions    = "true",
    preserve_insertion_order     = "false" ) )
  ensure_httpfs( con )
  dbExecute( con, sprintf( "SET s3_region='%s';", REGION ) )
  con
}

# ---- list the published CSVs ---------------------------------------------

list_prefix <- function( prefix ) {

  keys <- character( 0 )
  sizes <- numeric( 0 )
  token <- NULL

  repeat {
    url <- sprintf( "https://%s.s3.%s.amazonaws.com/?list-type=2&prefix=%s&max-keys=1000",
                    BUCKET, REGION, utils::URLencode( prefix, reserved = TRUE ) )
    if ( ! is.null( token ) ) {
      url <- paste0( url, "&continuation-token=", utils::URLencode( token, reserved = TRUE ) )
    }
    xml <- paste( readLines( url, warn = FALSE ), collapse = "" )

    k <- regmatches( xml, gregexpr( "(?<=<Key>)[^<]+", xml, perl = TRUE ) )[[ 1 ]]
    s <- regmatches( xml, gregexpr( "(?<=<Size>)[^<]+", xml, perl = TRUE ) )[[ 1 ]]
    keys  <- c( keys, k )
    sizes <- c( sizes, as.numeric( s ) )

    t <- regmatches( xml, regexpr( "(?<=<NextContinuationToken>)[^<]+", xml, perl = TRUE ) )
    if ( ! length( t ) ) break
    token <- t
  }

  keep <- grepl( "\\.CSV$", keys, ignore.case = TRUE )
  data.frame( key = keys[ keep ], size = sizes[ keep ],
              prefix = prefix, stringsAsFactors = FALSE )
}

# ---- one file -------------------------------------------------------------

convert_one <- function( row, con ) {

  key      <- row$key
  base     <- sub( "\\.CSV$", "", basename( key ), ignore.case = TRUE )
  rel_dir  <- dirname( key )
  csv_url  <- sprintf( "https://%s.s3.%s.amazonaws.com/%s", BUCKET, REGION, key )

  stage_csv <- file.path( STAGE_DIR, basename( key ) )
  stage_pq  <- file.path( STAGE_DIR, paste0( base, ".parquet" ) )

  t0 <- Sys.time()

  # Stage the CSV locally. Converting straight from the URL works, but a
  # 1.76 GB input plus an ORDER BY means DuckDB re-reads it, and a local file
  # makes that cheap and the run resumable.
  utils::download.file( csv_url, stage_csv, mode = "wb", quiet = TRUE )

  rel <- sprintf( "read_csv('%s', all_varchar = true, sample_size = -1)",
                  gsub( "\\\\", "/", stage_csv ) )
  flds <- dbGetQuery( con, sprintf( "DESCRIBE SELECT * FROM %s", rel ) )$column_name
  q    <- function( x ) paste0( '"', gsub( '"', '""', x ), '"' )

  sel <- if ( FOLD_EMPTY ) {
    paste( sprintf( "NULLIF(%s, '') AS %s", q( flds ), q( flds ) ), collapse = ", " )
  } else "*"

  order_by <- if ( SORT_KEY %in% flds ) paste0( " ORDER BY ", q( SORT_KEY ) ) else ""

  dbExecute( con, sprintf(
    "COPY ( SELECT %s FROM %s%s ) TO '%s' ( FORMAT parquet, COMPRESSION %s, COMPRESSION_LEVEL %d, ROW_GROUP_SIZE %d );",
    sel, rel, order_by, gsub( "\\\\", "/", stage_pq ),
    COMPRESSION, COMP_LEVEL, ROW_GROUP ) )

  # Verify: hash every row, aggregate the hashes in sorted order. Order- and
  # key-independent, which matters because OBJECTID is not unique in the
  # repeating-group tables -- F9-P07-T02-CONTRACTORS-2023 has 299,205 rows but
  # only 215,278 distinct OBJECTIDs, so any ORDER BY OBJECTID digest is
  # non-deterministic among ties and reports a false mismatch.
  ok <- NA
  n_csv <- n_pq <- NA_real_
  if ( VERIFY ) {
    cell <- if ( FOLD_EMPTY ) sprintf( "nullif(%s, '')", q( flds ) ) else q( flds )
    expr <- paste( sprintf( "coalesce(%s, '<<NULL>>')", cell ), collapse = ", " )
    dig <- function( r ) dbGetQuery( con, sprintf(
      "SELECT md5( string_agg( h, '' ORDER BY h ) ) AS d, count(*) AS n FROM ( SELECT md5( concat_ws( '<|>', %s ) ) AS h FROM %s )",
      expr, r ) )
    a <- dig( rel )
    b <- dig( sprintf( "read_parquet('%s')", gsub( "\\\\", "/", stage_pq ) ) )
    ok    <- identical( a$d, b$d ) && identical( a$n, b$n )
    n_csv <- a$n
    n_pq  <- b$n
  }

  dest <- NA_character_
  if ( isTRUE( ok ) || ! VERIFY ) {
    if ( DEST_MODE == "s3" ) {
      dest <- paste0( DEST_S3, sub( "^public/", "", rel_dir ), "/", base, ".parquet" )
      dbExecute( con, sprintf( "COPY ( SELECT * FROM read_parquet('%s') ) TO '%s' ( FORMAT parquet, COMPRESSION %s, COMPRESSION_LEVEL %d, ROW_GROUP_SIZE %d );",
                               gsub( "\\\\", "/", stage_pq ), dest,
                               COMPRESSION, COMP_LEVEL, ROW_GROUP ) )
    } else {
      dest_dir <- file.path( DEST_LOCAL, sub( "^public/", "", rel_dir ) )
      dir.create( dest_dir, showWarnings = FALSE, recursive = TRUE )
      dest <- file.path( dest_dir, paste0( base, ".parquet" ) )
      file.copy( stage_pq, dest, overwrite = TRUE )
    }
  }

  out <- data.frame(
    key        = key,
    table      = base,
    csv_mb     = round( row$size / 1e6, 2 ),
    parquet_mb = round( file.size( stage_pq ) / 1e6, 2 ),
    ratio      = round( row$size / file.size( stage_pq ), 2 ),
    n_csv      = n_csv,
    n_pq       = n_pq,
    verified   = ok,
    dest       = dest,
    secs       = round( as.numeric( difftime( Sys.time(), t0, units = "secs" ) ), 1 ),
    stringsAsFactors = FALSE )

  unlink( stage_pq )
  if ( ! KEEP_CSV ) unlink( stage_csv )
  out
}

# ---- driver ---------------------------------------------------------------

run_conversion <- function( prefixes = PREFIXES, limit = NULL, dry_run = FALSE ) {

  dir.create( STAGE_DIR,  showWarnings = FALSE, recursive = TRUE )
  dir.create( DEST_LOCAL, showWarnings = FALSE, recursive = TRUE )

  todo <- do.call( rbind, lapply( prefixes, list_prefix ) )
  todo <- todo[ order( todo$size ), ]          # cheap files first, fail fast
  if ( ! is.null( limit ) ) todo <- utils::head( todo, limit )

  message( sprintf( "%d CSV files, %.1f GB total", nrow( todo ), sum( todo$size ) / 1e9 ) )
  if ( dry_run ) return( invisible( todo ) )

  # Resume: skip anything already recorded as verified. A FAIL row is left in
  # the manifest but not skipped, so a re-run retries it.
  done <- character( 0 )
  if ( file.exists( MANIFEST ) ) {
    prev <- utils::read.csv( MANIFEST, stringsAsFactors = FALSE )
    done <- unique( prev$key[ as.character( prev$verified ) == "TRUE" ] )
    message( sprintf( "resuming: %d already verified, %d to go",
                      length( done ), sum( ! todo$key %in% done ) ) )
  }
  todo <- todo[ ! todo$key %in% done, ]

  con <- open_con()
  on.exit( dbDisconnect( con, shutdown = TRUE ), add = TRUE )

  for ( i in seq_len( nrow( todo ) ) ) {
    row <- todo[ i, ]
    res <- tryCatch( convert_one( row, con ),
                     error = function( e ) data.frame(
                       key = row$key, table = basename( row$key ),
                       csv_mb = round( row$size / 1e6, 2 ), parquet_mb = NA_real_,
                       ratio = NA_real_, n_csv = NA_real_, n_pq = NA_real_,
                       verified = FALSE, dest = NA_character_, secs = NA_real_,
                       stringsAsFactors = FALSE ) )

    utils::write.table( res, MANIFEST, sep = ",", row.names = FALSE,
                        col.names = ! file.exists( MANIFEST ),
                        append = file.exists( MANIFEST ), qmethod = "double" )

    message( sprintf( "[%4d/%4d] %-46s %8.1f -> %7.1f MB  %5.1fx  %s  %ss",
                      i, nrow( todo ), res$table, res$csv_mb, res$parquet_mb,
                      res$ratio,
                      if ( isTRUE( res$verified ) ) "OK  " else "FAIL",
                      res$secs ) )
  }

  message( "manifest: ", MANIFEST )
  invisible( utils::read.csv( MANIFEST, stringsAsFactors = FALSE ) )
}

# ---- usage ----------------------------------------------------------------
#
#   source( "dev/convert-s3-csv-to-parquet.R" )
#
#   run_conversion( dry_run = TRUE )        # inventory only, nothing written
#   run_conversion( limit = 5 )             # smoke test on the 5 smallest
#   run_conversion()                        # all 3,586 files
#
# Uploading to S3 needs credentials in the session:
#   DEST_MODE <- "s3"
#   ef2::configure_aws_credentials( con )
#
# Expect roughly 6x compression: 194 GB of CSV becomes about 33 GB of Parquet.
# ---------------------------------------------------------------------------
