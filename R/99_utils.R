
#' Extract an OBJECTID from a filing URL
#'
#' Converts known IRS 990 e-file XML URLs into a standardized OBJECTID
#' (prefixed with `OID-`) used as a database key.
#'
#' @param url Character. Full XML URL.
#' @return Character scalar OBJECTID.
#' @examples
#' get_object_id2("https://nccs-efile.s3.us-east-1.amazonaws.com/xml/202220139349301207_public.xml")
#' @export
get_object_id2 <- function (url) {
  base_01 <- "https://gt990datalake-rawdata.s3.amazonaws.com/EfileData/XmlFiles/"
  base_02 <- "https://nccs-efile.s3.us-east-1.amazonaws.com/xml/"
  base_03 <- "https://nccs-efile.s3.us-east-1.amazonaws.com/xml2/2022_TEOS_XML_01A/"
  base_04 <- "https://nccs-efile.s3.us-east-1.amazonaws.com/xml2/2022_TEOS_XML_02A/"
  object.id <- gsub(paste0(base_01,"|",base_02,"|",base_03,"|",base_04), "", url)
  object.id <- gsub("_public.xml", "", object.id)
  object.id <- paste0("OID-", object.id)
  return(object.id)
}

#' Format Employer Identification Numbers (EINs)
#'
#' @description
#' Converts between numeric EINs (e.g., `"123456789"`) and standardized
#' ID-style EINs (e.g., `"EIN-12-3456789"`).
#'
#' This utility ensures EINs are properly zero-padded to nine digits and
#' formatted consistently for joining or matching across datasets.
#'
#' @param x Character or numeric vector of EINs. Can contain mixed formats
#'   (e.g., `"123456789"`, `"EIN-12-3456789"`, or `"12-3456789"`).
#' @param to Character. Direction of formatting:
#'   \describe{
#'     \item{`"id"`}{Convert to standardized EIN ID format (`"EIN-XX-XXXXXXX"`).}
#'     \item{`"n"`}{Convert to numeric-only form (digits only, no punctuation or prefix).}
#'   }
#'
#' @return A character vector of reformatted EINs.
#'
#' @examples
#' # Convert to EIN ID format
#' format_ein(c("123456789", "987654321"), to = "id")
#' #> [1] "EIN-12-3456789" "EIN-98-7654321"
#'
#' # Convert back to numeric-only
#' format_ein(c("EIN-12-3456789", "EIN-98-7654321"), to = "n")
#' #> [1] "123456789" "987654321"
#'
#' @export
format_ein <- function(x, to = "id") {
  # Ensure input is character
  x <- as.character(x)

  # Normalize and route based on target format
  if (to == "id") {
    # Keep only digits and pad to 9 characters
    x <- gsub("[^0-9]", "", x)
    x <- stringr::str_pad(x, 9, side = "left", pad = "0")

    # Split and rebuild EIN format
    sub1 <- substr(x, 1, 2)
    sub2 <- substr(x, 3, 9)
    ein  <- paste0("EIN-", sub1, "-", sub2)
    return(ein)
  }

  if (to == "n") {
    # Remove non-numeric characters
    x <- gsub("[^0-9]", "", x)
    return(x)
  }

  # Handle invalid direction argument
  stop("Invalid value for argument 'to'. Use 'id' or 'n'.")
}


#' Extract the last bracketed index from an xpath
#'
#' For an xpath like "`/Return/.../ScheduleO[3]/.../Line[12]`" returns "12".
#'
#' @param x Character scalar xpath.
#' @return Character index (defaults to "0" if none).
#' @export
get_n <- function(x) {
  matches <- stringr::str_extract_all(x, "\\[\\d+\\]")[[1]]
  if (length(matches) >= 1) {
    N <- tail(matches, 1)
    N <- stringr::str_remove_all(N, "\\[|\\]")  # <-- fixed
    return(N)
  } else {
    return("0")
  }
}

#' Make a TABLE_ID from a vector of xpaths
#'
#' @param xpaths Character vector of xpaths.
#' @return Character vector like "TID-00003".
#' @export
get_table_id <- function( xpaths ) {
  # Vectorized get_n(): the last "[digits]" index in each xpath, "0" if none.
  # Same result as sapply(xpaths, get_n), without one regex call per element.
  table.n <- rep( "0", length(xpaths) )
  has.n   <- grepl( "\\[[0-9]+\\]", xpaths )
  table.n[has.n] <- sub( "^.*\\[([0-9]+)\\].*$", "\\1", xpaths[has.n] )
  table.n <- sprintf( "%05.0f", as.numeric(table.n) )
  table.n <- paste0( "TID-", table.n )
  return( table.n )  
}

#' Remove default namespaces from a document (fast xml_ns_strip)
#'
#' Same result as `xml2::xml_ns_strip()`, which removes `xmlns` from every
#' element that has a default namespace *in scope*. Every element inherits the
#' root's namespace, so it touches every element, and each removal also walks
#' the element's subtree: quadratic in document size (642 s for a 31.5 MB
#' 990-PF return with 505,796 elements). Removing the declaration from the
#' topmost elements that carry it clears the whole subtree in one pass; the
#' loop repeats in case a nested element redeclares a different default.
#'
#' @param x An `xml2` document.
#' @return `x`, invisibly (modified in place, like `xml2::xml_ns_strip()`).
#' @export
xml_ns_strip_fast <- function( x ){
  # Every element with a default namespace in scope has a topmost such
  # ancestor (or is one), so an empty `topmost` set means nothing is left.
  # Selecting all in-scope elements instead took 230 s on the 31.5 MB return.
  topmost  <- "//*[namespace::*[name()=''] and not(parent::*[namespace::*[name()='']])]"
  for ( i in 1:50 ) {
    nodes <- xml2::xml_find_all( x, topmost )
    if ( !length( nodes ) ) break
    xml2::xml_attr( nodes, "xmlns" ) <- NULL
  }
  invisible( x )
}

#' Xpaths of every element, in document order
#'
#' The same result as `xml2::xml_path(xml2::xml_find_all(doc, "//*"))`, in
#' linear time. libxml2 builds each path by scanning the element's siblings,
#' which is quadratic when one parent has many children (a 990-PF grant list
#' with tens of thousands of entries took 4-7 minutes; returns of 250+ MB
#' would take hours). Here each parent's children are named once: an element
#' gets "[k]" only when a sibling has the same name, as libxml2 does.
#'
#' Documents with elements still in a namespace after `xml_ns_strip()` (see
#' EF2-11) fall back to `xml2::xml_path()`, which writes the prefixes.
#'
#' @param doc An `xml2` document (namespaces stripped).
#' @return Character vector of xpaths, one per element, in document order.
#' @export
get_xml_paths <- function( doc ){
  # Only elements in a namespace change the path; IRS returns keep an xsi:
  # declaration that is used by an attribute alone, which does not.
  if ( xml2::xml_find_lgl( doc, "boolean(//*[namespace-uri() != ''])" ) ) {
    return( xml2::xml_path( xml2::xml_find_all( doc, "//*" ) ) )
  }
  nodes <- xml2::xml_find_all( doc, "//*" )          # document order
  n <- length( nodes )
  if ( !n ) return( character() )
  nm    <- xml2::xml_name( nodes )
  depth <- as.integer( xml2::xml_find_num( nodes, "count(ancestor::*)" ) )

  # parent = the closest preceding element one level up (document order)
  parent <- integer( n )
  for ( d in seq_len( max(depth) ) ) {
    here <- which( depth == d )
    up   <- which( depth == d - 1L )
    parent[here] <- up[ findInterval( here, up ) ]
  }

  # "[k]" only when another child of the same parent has the same name
  k   <- data.table::rowid( parent, nm )
  key <- paste( parent, nm, sep = "\r" )
  dup <- key %in% key[ duplicated(key) ]
  seg <- ifelse( dup, paste0( nm, "[", k, "]" ), nm )

  path <- character( n )
  path[depth == 0L] <- paste0( "/", seg[depth == 0L] )
  for ( d in seq_len( max(depth) ) ) {
    here <- which( depth == d )
    path[here] <- paste0( path[ parent[here] ], "/", seg[here] )
  }
  path
}

#' Compute the TABLE_HEADER from an xpath
#'
#' @param xpath Character scalar xpath.
#' @param type One of "parent" or "terminal".
#' @return Character scalar header xpath (two-level context).
#' @export
get_header <- function( xpath, type ){
  px <- strsplit( xpath, "\\/" ) |> unlist()
  px <- px[ px != "" ]

  if( length(px) > 2 ) { hd <- px[(length(px)-2):length(px)] }
  if( length(px) <= 2 ) { hd <- px }

  if( type == "parent" )   { hd <- hd[ - 1 ] }
  if( type == "terminal" ) { hd <- hd[ - length(hd) ] }

  header <- paste0( "//", paste0( hd, collapse="/" ) )
  return(header)
}

#' Find parent node xpaths for a set of xpaths
#'
#' @param xpath_list Character vector.
#' @return Character vector of unique parent xpaths.
#' @export
find_parent_nodes <- function(xpath_list) {
  # Every proper prefix (ending before a "/") of every xpath, in the order the
  # sorted input first reaches it -- the same result as the original nested
  # loop, which grew a vector and searched a list of names on every step and
  # so took hours on large filings.
  xpath_list <- sort(xpath_list)
  parts <- strsplit(xpath_list, "/", fixed = TRUE)
  parents <- unlist(lapply(parts, function(p) {
    n <- length(p) - 1
    if (n < 1) return(character())
    vapply(seq_len(n), function(i) paste(p[1:i], collapse = "/"), character(1))
  }), use.names = FALSE)
  return(unique(parents))
}

#' Find terminal node xpaths for a set of xpaths
#'
#' @param xpath_list Character vector.
#' @return Character vector of terminal xpaths.
#' @export
find_terminal_nodes <- function(xpath_list) {
  # An xpath is terminal when the next one in sorted order does not extend it.
  # Vectorized form of the original loop (same sort, same test, same output);
  # the loop grew its result with c() and was quadratic on large filings.
  xpath_list <- sort(xpath_list)
  if (!length(xpath_list)) return(NULL)
  nxt <- c(xpath_list[-1], "")
  is_terminal <- !startsWith(nxt, paste0(xpath_list, "/"))
  is_terminal[length(xpath_list)] <- TRUE
  return(xpath_list[is_terminal])
}

#' Classify xpaths as parent or terminal
#'
#' @param xpath Character vector of xpaths.
#' @return Character vector with values "parent" or "terminal".
#' @export
get_type <- function(xpath){
  parent_xpaths <- find_parent_nodes(xpath)
  terminal_xpaths <- find_terminal_nodes(xpath)
  type <- rep( "", length(xpath) )
  type[ xpath %in% parent_xpaths ]   <- "parent"
  type[ xpath %in% terminal_xpaths ] <- "terminal"
  return(type)
}

#' Get the last node name from an xpath
#'
#' @param x Character scalar xpath.
#' @return Character node name.
#' @export
get_xpath_vname <- function(x){
  last.x <- strsplit( x, "\\/" ) |> unlist() |> dplyr::last()
  return(last.x)
}

#' Vectorized variable name extraction from xpaths
#'
#' @param xpath Character vector.
#' @param type Character vector (ignored; reserved for future behavior).
#' @return Character vector of variable names.
#' @export
get_vnames <- function(xpath,type){
  vname <- purrr::map_chr( xpath, get_xpath_vname )
  return(vname)
}


