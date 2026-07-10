
#' Extract all XML node attributes into a tidy data frame
#'
#' Each attribute is returned as one row with columns:
#' OBJECTID, node_name, xpath, attr_name, and attr_value.
#'
#' @param doc Parsed XML document (xml2::read_xml()).
#' @param url Source URL of the XML file (used to derive OBJECTID).
#' @return A tidy data frame with one row per attribute.
#' @export
get_attr_df <- function(doc, url) {
  # Find all nodes that have attributes
  nodes_with_attrs <- xml2::xml_find_all(doc, "//*[@*]")

  # Build tidy attribute table
  attr_df <- purrr::map_df(nodes_with_attrs, function(node) {
    attrs <- xml2::xml_attrs(node)
    if (length(attrs) == 0) {
      return(NULL)
    }
    data.frame(
      node_name  = xml2::xml_name(node),
      xpath      = xml2::xml_path(node),
      attr_name  = names(attrs),
      attr_value = unname(as.character(attrs)),
      stringsAsFactors = FALSE
    )
  })

  # Add OBJECTID
  OBJECTID <- get_object_id2(url)
  df <- dplyr::mutate(attr_df, OBJECTID = OBJECTID, .before = 1)

  return(df)
}

#' Flatten an IRS 990 XML document to long-form rows
#'
#' @param doc An `xml2` document.
#' @param url Source URL for this filing.
#' @param ccf Optional concordance crosswalk (data frame) with columns xpath, variable_name, rdb_table.
#' @return Data frame with columns: OBJECTID, ORDER, XPATH, XPATH2, TABLE_HEADER, TABLE_ID, TYPE, RDB_TABLE, VARIABLE_NAME, VALUE.
#' @export
flatten_xml <- function( doc, url, ccf=NULL ){
  if( is.null(ccf) ){
    ccf <- get_concordance() |> as.data.frame()
    ccf <- ccf[c("xpath","variable_name","rdb_table")]
    names(ccf) <- toupper(names(ccf))
  }

  xx <- 
    doc %>% 
    xml2::xml_find_all("//*") %>% 
    xml2::xml_path()

  order <- seq_along(xx)
  type  <- get_type(xx)
  xx2   <- gsub( "\\[[0-9]{1,5}\\]", "", xx )
  xx2   <- gsub( "irs:", "", xx2 )
  xx2   <- gsub( "efile:", "", xx2 )

  table.id     <- get_table_id( xx )
  table.header <- purrr::map2_chr( xx2, type, get_header )
  OBJECTID     <- get_object_id2( url )
  VERSION      <- xml2::xml_attr( doc, attr='returnVersion' )

  tt <- 
    doc %>% 
    xml2::xml_find_all("//*") %>% 
    xml2::xml_text()

  if (length(tt) >= 1) tt[1] <- paste0( "VERSION: ", VERSION )

  d <- 
    data.frame(
      OBJECTID,
      ORDER=order,  
      XPATH=xx, 
      XPATH2=xx2, 
      TYPE=type, 
      TABLE_ID=table.id, 
      TABLE_HEADER=table.header, 
      VALUE=tt,
      stringsAsFactors = FALSE
    )

  dd <- merge( d, ccf, by.x="XPATH2", by.y="XPATH", all.x=TRUE )

  vnames <- get_vnames( dd$XPATH2, dd$TYPE )
  dd$VARIABLE_NAME[ is.na(dd$VARIABLE_NAME) ] <- vnames[ is.na(dd$VARIABLE_NAME) ]
  dd$RDB_TABLE[ is.na(dd$RDB_TABLE) ] <- ""
  dd <- dplyr::arrange( dd, .data$ORDER )

  column.order <-
    c("OBJECTID", "ORDER", "XPATH", "XPATH2",
      "TABLE_HEADER", "TABLE_ID", "TYPE",  
      "RDB_TABLE", "VARIABLE_NAME", "VALUE")

  dd <- as.data.frame(dd)
  dd <- dd[column.order]
  return(dd)
}

#' Download, parse, and flatten a single XML filing (with retries)
#'
#' @param url Character XML URL.
#' @param ccf Optional concordance crosswalk.
#' @param retries Integer retries.
#' @param pause_min,pause_max Random backoff bounds in seconds.
#' @return List with FLATXML, ATTRIBUTES, and KEYS (see [get_keys()]).
#' @export
get_flat_xml <- function(url, ccf = NULL, retries = 3, pause_min = 1, pause_max = 4) {
  RES <- list(FAILED_URLS = data.frame(failed_urls = url, stringsAsFactors = FALSE))
  doc <- NULL

  for (attempt in seq_len(retries)) {
    try({
      resp <- httr::GET(url)
      if (httr::status_code(resp) == 200) {
        raw_xml <- httr::content(resp, as = "text", encoding = "UTF-8")
        doc <- xml2::read_xml(raw_xml)
        break
      }
    }, silent = TRUE)

    if (is.null(doc)) {
      delay <- runif(1, pause_min, pause_max)
      cat(sprintf("Retrying (%d/%d) after %.1f sec: %s\n",
                  attempt, retries, delay, url))
      Sys.sleep(delay)
    }
  }

  if (is.null(doc)) {
    cat(paste0("\u274C FAIL: ", url, "\n"))
    return(RES)
  }

  xml2::xml_ns_strip(doc)
  KEYS       <- get_keys(doc, url) |> as.data.frame()
  FLATXML    <- flatten_xml(doc, url, ccf)
  ATTRIBUTES <- get_attr_df(doc, url)

  list(FLATXML = FLATXML, ATTRIBUTES = ATTRIBUTES, KEYS = KEYS)
}


#' Flatten a batch of XML filings and write to DuckDB
#'
#' Sequentially downloads and parses a batch of XML files, flattens them,
#' and writes results to KEYS, FLATXML, and ATTRIBUTES tables
#' within a single DuckDB transaction.
#'
#' @param batch Character vector of XML URLs.
#' @param con Active DBI connection to DuckDB.
#' @param ccf Concordance crosswalk (prepared via prep_concordance()).
#' @param quietly Logical; if FALSE, print per-file progress.
#' @return Invisibly, the number of successfully processed XMLs.
#' @export
batch_flatten <- function(batch, con, ccf, quietly=TRUE) {
  # --- Safety guard: ensure temp directory exists ---
  if (!dir.exists(tempdir())) dir.create(tempdir(), recursive = TRUE)
  Sys.setenv(TMPDIR = tempdir())

  # --- Sequential processing for stability ---
  results <- vector("list", length(batch))
  failed  <- character(0)

  for (i in seq_along(batch)) {
    url <- batch[[i]]
    if(!quietly){ cat(sprintf("  [%02d/%02d] %s\n", i, length(batch), basename(url))) }
    res <- try(get_flat_xml(url, ccf), silent = TRUE)
    if (inherits(res, "try-error") || is.null(res$FLATXML)) {
      cat("  \u274C Failed:", url, "\n")
      failed <- c(failed, url)
    } else {
      results[[i]] <- res
    }
  }

  # --- Filter out NULL entries ---
  results <- purrr::compact(results)

  # --- Report ---
  cat("  \u2705 Completed batch with", length(results), "records.",
      if (length(failed)) paste("(", length(failed), "failed )\n") else "\n")

  # --- Write results to DuckDB ---
  if (length(results) > 0) {
    DBI::dbExecute(con, "BEGIN TRANSACTION;")
    send_flat_xml_to_db(RESULTS = results, con = con)
    DBI::dbExecute(con, "COMMIT;")
  }


  invisible(length(results))
}
