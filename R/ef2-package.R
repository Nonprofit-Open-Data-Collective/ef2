#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom dplyr %>%
#' @importFrom stats runif
#' @importFrom utils download.file head read.csv tail
## usethis namespace: end
NULL

# Quiet R CMD check NOTEs for non-standard evaluation. These names are column
# references inside dplyr / data.table pipelines (plus the rlang `.data`
# pronoun), not undefined global variables.
utils::globalVariables(c(
  ".data",
  "ReturnTs",
  "xpath", "count_occurrences", "schema_versions",
  "attr_name", "attr_value", "n_records", "OBJECTID",
  "table_name", "n_rows", "db", "worker_sum", "n_workers"
))
