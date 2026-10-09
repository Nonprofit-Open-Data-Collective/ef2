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
  "table_name", "n_rows", "db", "worker_sum", "n_workers",
  # 12_patch_index.R (data.table columns)
  "XML_BATCH_ID", "INDEX_YEAR", "RETURN_TYPE", "OBJECT_ID", "ZIP_FILE",
  "ObjectId", "URL", "ZipFile", "PATCH_BUILD", "PATCH_CREATED", "SOURCE",
  ".N", ".SD", "..cols",
  # 13_release_notes.R (data.table columns)
  "table", "year", "file", "file_name", "name", "rows", "ncol", "version", "column",
  "change", "years", "N", "rows_old", "rows_new", "ncol_old", "ncol_new", "d_rows", "d_cols",
  "return_type", "old", "new", "variable_name", "rdb_table", "variable_name_old",
  "variable_name_new", "rdb_table_old", "rdb_table_new", "multi_value_old", "multi_value_new",
  "from", "to"
))

# ef2 does not import data.table, so data.table's `[` must be told that this
# namespace uses its syntax (`:=`, `.N`, `..cols`).
.datatable.aware <- TRUE
