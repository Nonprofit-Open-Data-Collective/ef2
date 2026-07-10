

#' Utility: split a vector into labeled groups
#'
#' @param x Vector to split.
#' @param G Group size.
#' @return Named list of groups.
#' @export
split_into_groups <- function (x, G = 25) {
  groups <- split(x, ceiling(seq_along(x)/G))
  n_groups <- length(groups)
  max_width <- max(nchar(n_groups))
  num_groups <- stringr::str_pad(1:n_groups, width = max_width, side = "left", pad = "0")
  len_groups <- sapply(groups, length)
  names(groups) <- paste0( "G", num_groups, "{", len_groups, "}" )
  return(groups)
}



#' Split a URL vector into named groups and persist RDS
#'
#' @param urls Character vector of URLs.
#' @param group.size Integer batch size.
#' @param path Directory in which to create the `batches/` subfolder.
#' @return Invisibly the batch list.
#' @export
split_urls <- function (urls, group.size = 25, path=".") {
  batchfile <- split_into_groups(urls, G = group.size)
  write_batches(batchfile,path)
  # dir.create(as.character(year), showWarnings = FALSE)
  # saveRDS(batchfile, paste0(year, "/BATCHFILE.RDS"))
  return(invisible(batchfile))
}



#' Write batch files to disk
#'
#' Persists each element of a batch list as a standalone `.R` file
#' containing an object named `x`. This allows parallel workers to
#' safely read and process batches without contention for a shared
#' `.RDS` file.
#'
#' @param batchfile Named list where each element contains a vector
#'   (e.g., URLs or filenames) to be processed in one batch.
#' @param path Directory in which to create the `batches/` subfolder.
#'   Defaults to the current working directory.
#'
#' @details
#' Each batch is written to a file named `batches/<batchname>.R` inside
#' the specified path. The function uses `purrr::iwalk()` to iterate over
#' the list, ensuring the batch name and data stay paired correctly.
#'
#' @return Invisibly returns `NULL`. Files are created as a side effect.
#' @examples
#' \dontrun{
#' batches <- list(G01 = c("file1.xml", "file2.xml"),
#'                 G02 = c("file3.xml", "file4.xml"))
#' write_batches(batches, path = "data/2021")
#' }
#' @export
write_batches <- function(batchfile, path = ".") {
  dir.create(file.path(path, "batches"), showWarnings = FALSE, recursive = TRUE)

  purrr::iwalk(batchfile, function(x, nm) {
    fn <- file.path(path, "batches", paste0(nm, ".R"))
    dump("x", file = fn)
  })
}


#' Remove a processed batch file
#'
#' Deletes the `.R` file corresponding to a processed batch, typically
#' after successful import into the database. This allows the build
#' process to resume later without reprocessing completed batches.
#'
#' @param batchname Character. Name of the batch (e.g., `"G01{25}"`).
#' @param path Directory containing the `batches/` subfolder.
#'
#' @return Invisibly returns `TRUE` if the file was removed successfully,
#'   otherwise `FALSE`.
#' @examples
#' \dontrun{
#' remove_batch("G01{25}", path = "data/2021")
#' }
#' @export
remove_batch <- function(batchname, path) {
  fn <- file.path(path, "batches", paste0(batchname, ".R"))
  if (file.exists(fn)) {
    file.remove(fn)
    message("Removed batch ", batchname)
    invisible(TRUE)
  } else {
    message("Batch ", batchname, " not found (already removed?)")
    invisible(FALSE)
  }
}


#' Load pending batch files from disk
#'
#' Reads all `.R` files from a `batches/` directory and reconstructs
#' them as a named list, where each element contains the object `x`
#' defined inside the file.
#'
#' @param path Directory containing a `batches/` subfolder.
#'   Defaults to the current working directory.
#'
#' @details
#' Each batch file is read in isolation using `sys.source()` into a
#' temporary environment to avoid polluting the global environment.
#' The result is a list of batches, with names derived from the
#' filenames (minus the `.R` extension).
#'
#' @return Named list of batch contents.
#' @examples
#' \dontrun{
#' batches <- gather_batches("data/2021")
#' names(batches)
#' }
#' @export
gather_batches <- function(path = ".") {
  batch_dir <- file.path(path, "batches")
  files <- list.files(batch_dir, pattern = "\\.R$", full.names = TRUE)

  L <- purrr::map(files, function(fn) {
    env <- new.env()
    sys.source(fn, envir = env)
    env$x
  })

  nmz <- gsub("\\.R$", "", basename(files))
  names(L) <- nmz
  return(L)
}





#' Create batchfiles (RDS) for multiple years
#'
#' @param index Data frame with URL and TaxYear.
#' @param years Vector of years (integer or character).
#' @param group.size Integer batch size.
#' @export
create_batchfiles <- function (index, years, group.size) {
  years <- as.character(years)
  purrr::walk(years, split_index, index = index, group.size = group.size)
}

#' Prepare an index for batching
#'
#' Filters an efiler index to the requested tax years and form types, and
#' removes duplicate filings (by URL). Ported from the `irs990efile` package.
#'
#' @param years Optional vector of tax years to keep. If NULL, all years in
#'   `index` are used.
#' @param index Data frame with at least `TaxYear`, `FormType`, and `URL`
#'   columns.
#' @param form.type Character vector of form types to keep
#'   (default `c("990", "990EZ")`).
#' @return A filtered, de-duplicated copy of `index`.
#' @export
prep_index <- function( years = NULL, index, form.type = c("990", "990EZ") ){
  if( missing(index) || is.null(index) ){
    stop( "prep_index() requires an 'index' data frame with TaxYear, FormType, and URL columns." )
  }
  if( is.null(years) ){ years <- unique( index[["TaxYear"]] ) }
  years <- sort( as.character( years ) )
  index <- dplyr::filter( index, as.character(.data$TaxYear) %in% years )
  index <- dplyr::filter( index, .data$FormType %in% form.type )
  index <- dplyr::distinct( index, .data$URL, .keep_all = TRUE )
  return( index )
}

#' Split index to batchfile RDS for a single year
#'
#' @param year Integer/character year.
#' @param index Data frame.
#' @param group.size Integer batch size.
#' @return Invisibly the batch list.
#' @export
split_index <- function (year, index, group.size = 25) {
  index <- prep_index(years = year, index)
  urls <- index[["URL"]]
  batchfile <- split_into_groups(urls, G = group.size)
  write_batches(batchfile)
  # dir.create(as.character(year), showWarnings = FALSE)
  # saveRDS(batchfile, paste0(year, "/BATCHFILE.RDS"))
  return(invisible(batchfile))
}

