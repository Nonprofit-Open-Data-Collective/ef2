#' Concordance of IRS e-file XPaths to standardized variables and tables
#'
#' A curated crosswalk used by ef2 to normalize XML element paths (XPaths)
#' into consistent variable names (`variable_name`) and logical table
#' assignments (`rdb_table`). It also includes labeling, versioning, and schema
#' hints to support stable flattening across IRS schema versions.
#'
#' @details
#' Columns are kept as character where feasible (including booleans and
#' version lists) to avoid lossy coercions; downstream code may cast types as
#' needed for analytics. The dataset is refreshed from the public source
#' when you run `data-raw/concordance.R`.
#'
#' @format
#' A data frame with the following columns:
#' \describe{
#'   \item{xpath}{Character. Unique XPaths derived from the IRS 990 e-file schema.}
#'   \item{variable_name}{Character. Standardized variable name used in outputs.}
#'   \item{rdb_relationship}{Character. Cardinality of tables (e.g., "ONE" for one-to-one).}
#'   \item{rdb_table}{Character. Logical table label (variables grouped by form parts/sections).}
#'   \item{label}{Character. Short human-readable label.}
#'   \item{description}{Character. Longer description of the field meaning.}
#'   \item{location_code_xsd}{Character. XSD-level location code (may be empty).}
#'   \item{location_code_family}{Character. Location family on the 990 form (e.g., "F990-PC-PART-00-LINE-00").}
#'   \item{location_code}{Character. Specific location on the form; for 990 this may match the family.}
#'   \item{form}{Character. IRS form, e.g., "F990", "F990EZ", "F990PF".}
#'   \item{form_type}{Character. Form subtype, e.g., "PC" for full 990; "EZ" for 990EZ; "HD" for header.}
#'   \item{form_part}{Character. Part identifier, e.g., "PART-00".}
#'   \item{form_line_number}{Character. Line identifier, e.g., "Line 00".}
#'   \item{variable_scope}{Character. Scope of variable (e.g., "HD" for header).}
#'   \item{data_type_xsd}{Character. Raw XSD type (e.g., "TimestampType", "StringType").}
#'   \item{data_type_simple}{Character. Simplified type such as "numeric", "text", "checkbox", "factor", "date".}
#'   \item{required}{Logical or character. Whether the field is required (may be NA).}
#'   \item{versions}{Character. Semicolon-separated schema versions where this mapping applies
#'                  (e.g., "2013v3.0;2014v5.0;2015v2.0").}
#'   \item{latest_version}{Integer or numeric or NA. Latest applicable version year if tracked.}
#'   \item{duplicated}{Logical or character. Whether this mapping duplicates another row for compatibility.}
#'   \item{current_version}{Logical or character. Marks mappings considered current/active.}
#'   \item{production_rule}{Character or NA. Optional rule hints for production pipelines.}
#'   \item{validated}{Character or NA. Optional validation flag or comments.}
#' }
#'
#' @source
#' Nonprofit-Open-Data-Collective: IRS e-file master concordance file.
#' \url{https://github.com/Nonprofit-Open-Data-Collective/irs-efile-master-concordance-file}
#'
#' @usage data(concordance)
#' @docType data
#' @name concordance
#' @keywords datasets
#'
#' @examples
#' data(concordance)
#' head(concordance)
NULL


#' @name index
#' @title IRS 990 e-filer index (structure reference)
#'
#' @description Describes the columns of the IRS 990 e-filer index returned by
#'  [get_current_index_full()] and [get_current_index_batch()]. This is a
#'  documentation-only reference for the index structure; the index is
#'  downloaded on demand from the Giving Tuesday Data Commons rather than
#'  shipped as package data.
#'
#' @format A data frame with 35 variables:
#' \describe{
#'   \item{BuildTs}{POSIXct: Timestamp indicating when the data was built.}
#'   \item{DAF}{Logical: Indicates if the record relates to a Donor-Advised Fund.}
#'   \item{DateSigned}{Date: The date the filing was signed.}
#'   \item{DocStatus}{Character: Status of the filing document (e.g., approved, pending).}
#'   \item{EIN}{Integer: Employer Identification Number of the organization.}
#'   \item{FileSha256}{Character: SHA-256 checksum of the file for integrity verification.}
#'   \item{FileSizeBytes}{Integer: Size of the file in bytes.}
#'   \item{FormType}{Character: Type of IRS Form 990 (e.g., "990", "990EZ").}
#'   \item{GrossReceipts}{Integer64: Gross receipts reported by the organization.}
#'   \item{GroupAffiliatesIncluded}{Logical: Indicates if group affiliates are included.}
#'   \item{GroupExemptionNumber}{Integer: Group exemption number if applicable.}
#'   \item{GroupReturnForAffiliates}{Logical: Indicates if the return is for group affiliates.}
#'   \item{IndexedOn}{Date: The date when the record was indexed.}
#'   \item{LegalDomicileCountry}{Character: Country of legal domicile of the organization.}
#'   \item{LegalDomicileState}{Character: State of legal domicile of the organization.}
#'   \item{ObjectId}{Integer64: Unique identifier for the object.}
#'   \item{OrgType}{Character: Type of organization (e.g., "Corp", "Association").}
#'   \item{OrganizationName}{Character: Name of the organization.}
#'   \item{ReturnTs}{POSIXct: Timestamp indicating when the return was submitted.}
#'   \item{ReturnVersion}{Character: Version of the IRS form used.}
#'   \item{SubmittedOn}{Date: Date when the return was submitted.}
#'   \item{TaxPeriod}{Date: Tax period associated with the filing.}
#'   \item{TaxPeriodBeginDate}{Date: Start date of the tax period.}
#'   \item{TaxPeriodEndDate}{Date: End date of the tax period.}
#'   \item{TaxStatus}{Character: Tax status of the organization (e.g., "501c3").}
#'   \item{TaxYear}{Integer: The tax year the filing corresponds to.}
#'   \item{TotalAssetsBkEOY}{Integer64: Total assets at the end of the year as per the organization's books.}
#'   \item{TotalExpensesCY}{Integer64: Total expenses for the current year.}
#'   \item{TotalLiabilitiesBkEOY}{Integer64: Total liabilities at the end of the year as per the organization's books.}
#'   \item{TotalNetAssetsBkEOY}{Integer64: Total net assets at the end of the year as per the organization's books.}
#'   \item{TotalRevenueCY}{Integer64: Total revenue for the current year.}
#'   \item{URL}{Character: URL to the raw XML file of the IRS 990 data.}
#'   \item{Website}{Character: Website of the organization.}
#'   \item{YearFormed}{Integer: The year the organization was formed.}
#'   \item{ZipFile}{Character: Name of the ZIP file if applicable.}
#' }
#'
#' @source Giving Tuesday: \url{https://990data.givingtuesday.org/}
#' @examples
#' \dontrun{
#' index <- get_current_index_full()
#' table(index$FormType,index$TaxYear) |> knitr::kable()
#' }
NULL