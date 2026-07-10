# -----------------------------------------------------------------------------
# Functions ported from the irs990efile package
#
# These functions were previously accessed via `irs990efile::` from within ef2.
# They have been copied here so that ef2 is self-contained and the irs990efile
# dependency can be sunset. Behavior is preserved from the originals; the only
# changes are documentation cleanup and reuse of ef2's own `format_ein()` and
# `get_concordance()` helpers (rather than duplicating them).
#
# Original source: https://github.com/Nonprofit-Open-Data-Collective/irs990efile
# -----------------------------------------------------------------------------


## ----------------------------------------------------------------------------
## KEYS EXTRACTION
## ----------------------------------------------------------------------------

#' Extract an OBJECTID from a filing URL
#'
#' Parses the unique object ID from an IRS 990 e-file XML URL and prefixes it
#' with `OID-`.
#'
#' @param url Character. Full XML URL.
#' @return Character scalar OBJECTID (e.g. `"OID-202301529349200315"`).
#' @examples
#' base <- "https://gt990datalake-rawdata.s3.amazonaws.com/EfileData/XmlFiles/"
#' get_object_id(paste0(base, "202301529349200315_public.xml"))
#' # "OID-202301529349200315"
#' @seealso [get_object_id2()] for a variant that also handles the TEOS xml2 URL bases.
#' @export
get_object_id <- function( url ){
  base_01 <- "https://gt990datalake-rawdata.s3.amazonaws.com/EfileData/XmlFiles/"
  base_02 <- "https://nccs-efile.s3.us-east-1.amazonaws.com/xml/"
  object.id <- gsub( paste0( base_01, "|", base_02 ), "", url)
  object.id <- gsub( "_public.xml", "", object.id )
  object.id <- paste0( "OID-", object.id )
  return(object.id)
}


#' Extract text from XML nodes
#'
#' Retrieves the text content of all nodes matching an XPath expression.
#'
#' @param doc An XML document object (from `xml2::read_xml()`).
#' @param TEMP_VAR Character. XPath expression specifying the nodes to retrieve.
#' @return A character vector of extracted text, or `NA` if no nodes match.
#' @examples
#' \dontrun{
#' retrieve_xml(doc, "//Return/ReturnHeader/TaxYr")
#' }
#' @export
retrieve_xml <- function( doc, TEMP_VAR ) {
  x <- xml2::xml_text( xml2::xml_find_all( doc, TEMP_VAR ) )
  if( length(x) == 0 ){ x <- NA }
  return(x)
}


#' Standardize boolean inputs
#'
#' Converts various string representations of true/false (e.g. "YES", "X", "1")
#' into a logical vector. `NA` values are treated as `FALSE`.
#'
#' @param x A vector of values to standardize.
#' @return A logical vector.
#' @examples
#' standardize_boole(c("YES", "NO", NA, "X"))
#' @export
standardize_boole <- function( x ){
  x[ is.na(x) ] <- FALSE
  x <- toupper( x )
  TF <- x %in% c("TRUE","YES","1","X")
  return( TF )
}


#' Create a named list from its arguments
#'
#' Constructs a list whose names are taken from the supplied argument
#' expressions. Empty or `NULL` elements are replaced with `NA`.
#'
#' @param ... Arguments to include in the list.
#' @return A named list.
#' @examples
#' namedList(a = 1, b = 2)
#' @export
namedList <- function(...){
    names <- as.list(substitute(list(...)))[-1L]
    result <- list(...)
    names(result) <- names
    result[sapply(result, function(x){length(x)==0})] <- NA
    result[sapply(result, is.null)] <- NA
    result
}


#' Get table keys for a single filing
#'
#' Collects the identifying metadata fields (OBJECTID, EIN, organization name,
#' tax period, return type/flags, etc.) that key every relational table built
#' from an IRS 990 e-file document. These are the "RDB keys" attached to every
#' one-to-one and one-to-many table so that unique tax filings can be
#' identified, filtered, and linked across tables.
#'
#' @param doc An XML document object (from `xml2::read_xml()`).
#' @param url Character. Source URL of the filing (stored as `URL` and used to
#'   derive the `OBJECTID`).
#' @return A named list of key fields for the filing, suitable for coercion to a
#'   one-row data frame:
#' \describe{
#'   \item{EIN2}{Employer Identification Number formatted as `EIN-XX-XXXXXXX` (see [format_ein()]).}
#'   \item{OBJECTID}{Unique filing identifier prefixed with `OID-`, derived from `url` (see [get_object_id()]).}
#'   \item{ORG_EIN}{Raw Employer Identification Number digits from the return header.}
#'   \item{ORG_NAME_L1}{Filing organization name, line 1.}
#'   \item{ORG_NAME_L2}{Filing organization name, line 2 (if present).}
#'   \item{RETURN_AMENDED_X}{Logical; `TRUE` if the filing is an amended return.}
#'   \item{RETURN_GROUP_X}{Logical; `TRUE` if the filing is a group return for affiliates.}
#'   \item{RETURN_PARTIAL_X}{Logical; `TRUE` if the tax period spans fewer than 360 days (partial-year return).}
#'   \item{RETURN_TAXPER_DAYS}{Number of days in the tax period (end minus begin, plus 1).}
#'   \item{RETURN_TIME_STAMP}{Timestamp when the return was created/submitted.}
#'   \item{RETURN_TYPE}{Return type (e.g. `"990"`, `"990EZ"`).}
#'   \item{TAX_PERIOD_BEGIN_DATE}{Tax period begin date.}
#'   \item{TAX_PERIOD_END_DATE}{Tax period end date.}
#'   \item{TAX_YEAR}{Tax year covered by the filing.}
#'   \item{URL}{Source URL of the raw XML filing.}
#'   \item{VERSION}{IRS schema version of the return (`returnVersion` attribute).}
#' }
#' @seealso [add_keys()], which attaches these keys to relational tables.
#' @examples
#' \dontrun{
#' doc <- xml2::read_xml(url)
#' xml2::xml_ns_strip(doc)
#' get_keys(doc, url)
#' }
#' @export
get_keys <- function( doc, url ){

  ## OBJECT ID
  OBJECTID <- get_object_id( url )

  ## URL
  URL <- url

  ## RETURN VERSION
  VERSION <- xml2::xml_attr( doc, attr='returnVersion' )

  ## F9_00_RETURN_TIME_STAMP: date and time the return was created
  V1 <- '//Return/ReturnHeader/ReturnTs'
  V2 <- '//Return/ReturnHeader/Timestamp'
  TEMP_F9_00_RETURN_TIME_STAMP <- paste( V1, V2 , sep='|' )
  RETURN_TIME_STAMP <- retrieve_xml( doc, TEMP_F9_00_RETURN_TIME_STAMP )

  ## F9_00_RETURN_TYPE
  V1 <- '//Return/ReturnHeader/ReturnType'
  V2 <- '//Return/ReturnHeader/ReturnTypeCd'
  TEMP_F9_00_RETURN_TYPE <- paste( V1, V2 , sep='|' )
  RETURN_TYPE <- retrieve_xml( doc, TEMP_F9_00_RETURN_TYPE )

  ## F9_00_RETURN_AMENDED_X: indicates an amended return
  V1 <- '//Return/ReturnData/IRS990/AmendedReturn'
  V2 <- '//Return/ReturnData/IRS990/AmendedReturnInd'
  V3 <- '//Return/ReturnData/IRS990/Form990PartI/AmendedReturn'
  V4 <- '//Return/ReturnData/IRS990EZ/AmendedReturn'
  V5 <- '//Return/ReturnData/IRS990EZ/AmendedReturnInd'
  TEMP_F9_00_RETURN_AMENDED_X <- paste( V1, V2, V3, V4, V5 , sep='|' )
  RETURN_AMENDED_X <- retrieve_xml( doc, TEMP_F9_00_RETURN_AMENDED_X )
  RETURN_AMENDED_X <- standardize_boole(  RETURN_AMENDED_X )

  ## F9_00_RETURN_GROUP_X: group return for affiliates?
  V1 <- '//Return/ReturnData/IRS990/Form990PartI/GroupReturnForAffiliates'
  V2 <- '//Return/ReturnData/IRS990/GroupReturn'
  V3 <- '//Return/ReturnData/IRS990/GroupReturnForAffiliates'
  V4 <- '//Return/ReturnData/IRS990/GroupReturnForAffiliatesInd'
  TEMP_F9_00_RETURN_GROUP_X <- paste( V1, V2, V3, V4 , sep='|' )
  RETURN_GROUP_X <- retrieve_xml( doc, TEMP_F9_00_RETURN_GROUP_X )
  RETURN_GROUP_X <- standardize_boole(  RETURN_GROUP_X )

  ## F9_00_TAX_PERIOD_BEGIN_DATE
  V1 <- '//Return/ReturnHeader/TaxPeriodBeginDate'
  V2 <- '//Return/ReturnHeader/TaxPeriodBeginDt'
  TEMP_F9_00_TAX_PERIOD_BEGIN_DATE <- paste( V1, V2 , sep='|' )
  TAX_PERIOD_BEGIN_DATE <- retrieve_xml( doc, TEMP_F9_00_TAX_PERIOD_BEGIN_DATE )

  ## F9_00_TAX_PERIOD_END_DATE
  V1 <- '//Return/ReturnHeader/TaxPeriodEndDate'
  V2 <- '//Return/ReturnHeader/TaxPeriodEndDt'
  TEMP_F9_00_TAX_PERIOD_END_DATE <- paste( V1, V2 , sep='|' )
  TAX_PERIOD_END_DATE <- retrieve_xml( doc, TEMP_F9_00_TAX_PERIOD_END_DATE )

  ## F9_00_ORG_NAME_L1
  V1 <- '//Return/ReturnHeader/Filer/BusinessName/BusinessNameLine1'
  V2 <- '//Return/ReturnHeader/Filer/BusinessName/BusinessNameLine1Txt'
  V3 <- '//Return/ReturnHeader/Filer/Name/BusinessNameLine1'
  TEMP_F9_00_ORG_NAME_L1 <- paste( V1, V2, V3 , sep='|' )
  ORG_NAME_L1 <- retrieve_xml( doc, TEMP_F9_00_ORG_NAME_L1 )

  ## F9_00_ORG_NAME_L2
  V1 <- '//Return/ReturnHeader/Filer/BusinessName/BusinessNameLine2'
  V2 <- '//Return/ReturnHeader/Filer/BusinessName/BusinessNameLine2Txt'
  V3 <- '//Return/ReturnHeader/Filer/Name/BusinessNameLine2'
  TEMP_F9_00_ORG_NAME_L2 <- paste( V1, V2, V3 , sep='|' )
  ORG_NAME_L2 <- retrieve_xml( doc, TEMP_F9_00_ORG_NAME_L2 )

  ## F9_00_TAX_YEAR
  V1 <- '//Return/ReturnHeader/TaxYear'
  V2 <- '//Return/ReturnHeader/TaxYr'
  TEMP_F9_00_TAX_YEAR <- paste( V1, V2 , sep='|' )
  TAX_YEAR <- retrieve_xml( doc, TEMP_F9_00_TAX_YEAR )

  ## F9_00_ORG_EIN
  ORG_EIN <- retrieve_xml(  doc, '/Return/ReturnHeader/Filer/EIN' )

  EIN2 <- format_ein( ORG_EIN )
  DAYS <- as.Date(TAX_PERIOD_END_DATE) - as.Date(TAX_PERIOD_BEGIN_DATE)
  RETURN_TAXPER_DAYS <- as.numeric(DAYS) + 1
  RETURN_PARTIAL_X <- RETURN_TAXPER_DAYS < 360

  var.list <-
  namedList(EIN2,OBJECTID,ORG_EIN,ORG_NAME_L1,ORG_NAME_L2,RETURN_AMENDED_X,RETURN_GROUP_X,RETURN_PARTIAL_X,RETURN_TAXPER_DAYS,RETURN_TIME_STAMP,RETURN_TYPE,TAX_PERIOD_BEGIN_DATE,TAX_PERIOD_END_DATE,TAX_YEAR,URL,VERSION)
  return( var.list )
}


## ----------------------------------------------------------------------------
## TABLE METADATA
## ----------------------------------------------------------------------------

#' Get RDB table names from the concordance file
#'
#' Retrieves the unique relational-table names defined in the concordance
#' `rdb_table` field.
#'
#' @param exclude Character vector of table-code substrings to drop (matched as
#'   `-<code>-`). Defaults to `c("T99")`, which removes the supplemental-info
#'   text tables.
#' @return A character vector of table names (e.g. `"F9-P01-T00-SUMMARY"`).
#' @examples
#' \dontrun{
#' get_table_names()
#' }
#' @export
get_table_names <- function( exclude = c("T99") ) {
  concordance <- get_concordance()
  table.names <- concordance[["rdb_table"]] |> unique()
  table.names <- table.names[ table.names != "" ]
  if (!is.null(exclude)) {
    exclude <- paste0("-", exclude, "-", collapse = "|")
    table.names <- table.names[!grepl(exclude, table.names)]
  }
  return(table.names)
}


#' Get table headers
#'
#' Returns a named list mapping one-to-many table identifiers (e.g.
#' `F9-P03-T01-PROGRAMS-OTHER`) to the character vectors of candidate XML paths
#' used to locate that table's repeating group across IRS schema versions.
#'
#' @return A named list. Names are table header identifiers; values are
#'   character vectors of XML paths for data extraction.
#' @examples
#' headers <- get_table_headers()
#' headers$`F9-P03-T01-PROGRAMS-OTHER`
#' @export
get_table_headers <- function(){

  TABLE.HEADERS <- list()

  TABLE.HEADERS$'F9-P03-T01-PROGRAMS-OTHER' <-
  c("//IRS990/ActivityOther", "//Form990PartIII/ActivityOther", "//IRS990/ProgramServiceAccomplishments",
  "//IRS990/ProgSrvcAccomActyOtherGrp", "//IRS990EZ/ProgSrvcAccomActyOtherGrp"
  )

  TABLE.HEADERS$'F9-P03-T02-PROGRAMS-EZ' <-
  c("//IRS990EZ/ProgramServiceAccomplishment", "//IRS990EZ/ProgramSrvcAccomplishmentGrp"
  )

  TABLE.HEADERS$'F9-P07-T01-COMPENSATION' <-
  c("//IRS990/Form990PartVIISectionA", "//IRS990/Form990PartVIISectionAGrp",
  "//IRS990/FrmrOfcrDirTrstOrKeyEmployee", "//IRS990/OfcrDirTrusteesOrKeyEmployee",
  "//IRS990EZ/Form990PartVIISectionA", "//IRS990EZ/Form990PartVIISectionAGrp",
  "//IRS990EZ/OfficerDirectorTrusteeEmplGrp", "//IRS990EZ/OfficerDirectorTrusteeKeyEmpl"
  )

  TABLE.HEADERS$'F9-P07-T01-COMPENSATION-HCE-EZ' <-
  c("//IRS990EZ/CompensationHighestPaidEmplGrp", "//IRS990EZ/CompensationOfHighestPaidEmpl",
  "//IRS990EZ/PartVIOfCompOfHghstPdEmplTxt", "//IRS990EZ/PartVIOfCompOfHighestPaidEmpl"
  )

  TABLE.HEADERS$'F9-P07-T02-CONTRACTORS' <-
  c("//IRS990/ContractorCompensation", "//IRS990/ContractorCompensationGrp",
  "//IRS990/Form990PartVIISectionB", "//IRS990EZ/CompensationOfHghstPdCntrctGrp",
  "//IRS990EZ/CompOfHghstPaidCntrctProfSer", "//IRS990EZ/PartVIAHghstPaidCntrctProfSer",
  "//IRS990EZ/PartVIHghstPdCntrctProfSrvcTxt")

  TABLE.HEADERS$'F9-P08-T01-REVENUE-PROGRAMS' <-
  c("//Form990PartVIII/ProgramServiceRevenue", "//IRS990/ProgramServiceRevenue",
  "//IRS990/ProgramServiceRevenueGrp")

  TABLE.HEADERS$'F9-P08-T02-REVENUE-MISC' <-
  c("//Form990PartVIII/OtherRevenueMisc", "//IRS990/OtherRevenueMisc", "//IRS990/OtherRevenueMiscGrp"
  )

  TABLE.HEADERS$'F9-P09-T01-EXPENSES-OTHER' <-
  c("//Form990PartIX/OtherExpenses", "//IRS990/OtherExpenses", "//IRS990/OtherExpensesGrp"
  )

  TABLE.HEADERS$'SA-P01-T01-PUBLIC-CHARITY-STATUS' <-
  c("//IRS990ScheduleA/Form990ScheduleAPartI", "//IRS990ScheduleA/OtherSupportSumAmt",
  "//IRS990ScheduleA/SumOfAmounts", "//IRS990ScheduleA/SupportedOrgInformation",
  "//IRS990ScheduleA/SupportedOrgInformationGrp"
  )

  TABLE.HEADERS$'SA-P06-T99-SUPPLEMENTAL-INFO' <-
  c("//IRS990ScheduleA/Form990ScheduleAPartIVGrp", "//IRS990ScheduleA/Form990ScheduleAPartVIGrp",
  "//IRS990ScheduleA/GeneralExplanation", "//IRS990ScheduleA/GeneralExplanationTxt"
  )

  TABLE.HEADERS$'SB-P01-T01-CONTRIBUTORS' <-
  c("//IRS990ScheduleB/ContributorInformationGrp", "//IRS990ScheduleB/ContributorInfo")

  TABLE.HEADERS$'SC-P01-T01-POLITICAL-ORGS-INFO' <-
  c("//Form990ScheduleCPartI/Sec527PolOrgs", "//IRS990ScheduleC/Sec527PolOrgs",
  "//IRS990ScheduleC/Section527PoliticalOrgGrp")

  TABLE.HEADERS$'SC-P04-T99-SUPPLEMENTAL-INFO' <-
  c("//IRS990ScheduleC/Form990ScheduleCPartIV", "//IRS990ScheduleC/SupplementalInformationDetail"
  )

  TABLE.HEADERS$'SD-P07-T01-INVESTMENTS-OTH-SECURITIES' <-
  c("//Form990ScheduleDPartVII/Other", "//IRS990ScheduleD/OtherSecurities",
  "//IRS990ScheduleD/OtherSecuritiesGrp")

  TABLE.HEADERS$'SD-P07-T01-INVESTMENTS-OTH-EQUITY' <-
  c("//IRS990ScheduleD/CloselyHeldEquityInterests", "//IRS990ScheduleD/CloselyHeldEquityInterestsGrp",
  "//Form990ScheduleDPartVII/CloselyHeldEquityInterests")

  TABLE.HEADERS$'SD-P07-T01-INVESTMENTS-OTH-DERIVATIVES' <-
  c("//IRS990ScheduleD/FinancialDerivatives", "//IRS990ScheduleD/FinancialDerivativesGrp",
  "//Form990ScheduleDPartVII/FinancialDerivatives")

  TABLE.HEADERS$'SD-P08-T01-INVESTMENTS-PROG-RLTD' <-
  c("//Form990ScheduleDPartVIII/InvestmentsProgramRelated", "//IRS990ScheduleD/InvestmentsProgramRelated",
  "//IRS990ScheduleD/InvstProgramRelatedOrgGrp")

  TABLE.HEADERS$'SD-P09-T01-OTH-ASSETS' <-
  c("//Form990ScheduleDPartIX/OtherAssets", "//IRS990ScheduleD/OtherAssets",
  "//IRS990ScheduleD/OtherAssetsOrgGrp")

  TABLE.HEADERS$'SD-P10-T01-OTH-LIABILITIES' <-
  c("//IRS990ScheduleD/Form990ScheduleDPartX", "//IRS990ScheduleD/OtherLiabilities",
  "//IRS990ScheduleD/OtherLiabilitiesOrgGrp")

  TABLE.HEADERS$'SD-P13-T99-SUPPLEMENTAL-INFO' <-
  c("//IRS990ScheduleD/Form990ScheduleDPartXIII", "//IRS990ScheduleD/Form990ScheduleDPartXIV",
  "//IRS990ScheduleD/SupplementalInformationDetail")

  TABLE.HEADERS$'SE-P02-T99-SUPPLEMENTAL-INFO' <-
  c("//IRS990ScheduleE/Form990ScheduleEPartII", "//IRS990ScheduleE/SupplementalInformationDetail"
  )

  TABLE.HEADERS$'SF-P01-T01-FRGN-ACTS-BY-REGION' <-
  c("//IRS990ScheduleF/AccountActivitiesOutsideUSGrp", "//IRS990ScheduleF/AcctsActvsOutUSTable",
  "//Form990ScheduleFPartI/AcctsActvsOutUSTable")

  TABLE.HEADERS$'SF-P02-T01-FRGN-ORG-GRANTS' <-
  c("//Form990ScheduleFPartII/GrantsToOrgsOutsideUS", "//IRS990ScheduleF/GrantsToOrgOutsideUSGrp",
  "//IRS990ScheduleF/GrantsToOrgsOutsideUS")

  TABLE.HEADERS$'SF-P03-T01-FRGN-INDIV-GRANTS' <-
  c("//IRS990ScheduleF/ForeignIndividualsGrantsGrp", "//Form990ScheduleFPartIII/GrantsToIndOutsideUS",
  "//IRS990ScheduleF/GrantsToIndOutsideUS")

  TABLE.HEADERS$'SF-P05-T99-EXPLANATION-TEXT' <-
  c("//IRS990ScheduleF/Form990ScheduleFPartIV", "//IRS990ScheduleF/Form990ScheduleFPartV",
  "//IRS990ScheduleF/SupplementalInformationDetail")

  TABLE.HEADERS$'SG-P01-T01-FUNDRAISERS-INFO' <-
  c("//Form990ScheduleGPartI/FundraiserActivityInformation", "//IRS990ScheduleG/FundraiserActivityInfoGrp",
  "//IRS990ScheduleG/FundraiserActivityInformation")

  TABLE.HEADERS$'SG-P02-T01-FUNDRAISING-EVENTS' <-
  c("//IRS990ScheduleG/EventsInformation", "//Form990ScheduleGPartII/EventsInformation",
  "//IRS990ScheduleG/FundraisingEventInformationGrp")

  TABLE.HEADERS$'SG-P04-T99-SUPPLEMENTAL-INFO' <-
  c("//IRS990ScheduleG/Form990ScheduleGPartIV", "//IRS990ScheduleG/SupplementalInformationDetail"
  )

  TABLE.HEADERS$'SH-P04-T01-COMPANY-JOINT-VENTURES' <-
  c("//IRS990ScheduleH/Form990ScheduleHPartIV", "//IRS990ScheduleH/ManagementCoAndJntVenturesGrp"
  )

  TABLE.HEADERS$'SH-P05-T01-HOSPITAL-FACILITY' <-
  c("//IRS990ScheduleH/Form990ScheduleHPartV", "//IRS990ScheduleH/Form990ScheduleHPartVSectionA",
  "//IRS990ScheduleH/HospitalFacilitiesGrp")

  TABLE.HEADERS$'SH-P05-T02-NON-HOSPITAL-FACILITY' <-
  c("//Form990ScheduleHPartVSectionC/OtherFacilities", "//OthHlthCareFcltsNotHospitalGrp/OthHlthCareFcltsGrp"
  )

  TABLE.HEADERS$'SH-P05-T99-SUPPLEMENTAL-INFO' <-
  c("//IRS990ScheduleH/SupplementalInformationGrp"
  )

  TABLE.HEADERS$'SH-P06-T99-SUPPLEMENTAL-INFO' <-
  c("//IRS990ScheduleH/Form990ScheduleHPartVI"
  )

  TABLE.HEADERS$'SI-P02-T01-GRANTS-US-ORGS-GOVTS' <-
  c("//Form990ScheduleIPartII/RecipientTable", "//IRS990ScheduleI/RecipientTable"
  )

  TABLE.HEADERS$'SI-P03-T01-GRANTS-US-INDIV' <-
  c("//IRS990ScheduleI/Form990ScheduleIPartIII", "//IRS990ScheduleI/GrantsOtherAsstToIndivInUSGrp"
  )

  TABLE.HEADERS$'SI-P04-T99-SUPPLEMENTAL-INFO' <-
  c("//IRS990ScheduleI/Form990ScheduleIPartIV", "//IRS990ScheduleI/SupplementalInformationDetail"
  )

  TABLE.HEADERS$'SJ-P02-T01-COMPENSATION-DTK' <-
  c("//IRS990ScheduleJ/Form990ScheduleJPartII", "//IRS990ScheduleJ/RltdOrgOfficerTrstKeyEmplGrp"
  )

  TABLE.HEADERS$'SJ-P03-T99-SUPPLEMENTAL-INFO' <-
  c("//IRS990ScheduleJ/Form990ScheduleJPartIII", "//IRS990ScheduleJ/SupplementalInformationDetail"
  )

  TABLE.HEADERS$'SK-P01-T01-BOND-ISSUES' <-
  c("//IRS990ScheduleK/Form990ScheduleKPartI", "//IRS990ScheduleK/TaxExemptBondsIssuesGrp"
  )

  TABLE.HEADERS$'SK-P02-T01-BOND-PROCEEDS' <-
  c("//IRS990ScheduleK/Form990ScheduleKPartII", "//IRS990ScheduleK/TaxExemptBondsProceedsGrp"
  )

  TABLE.HEADERS$'SK-P03-T01-BOND-PRIVATE-BIZ-USE' <-
  c("//IRS990ScheduleK/Form990ScheduleKPartIII", "//IRS990ScheduleK/TaxExemptBondsPrivateBusUseGrp"
  )

  TABLE.HEADERS$'SK-P04-T01-BOND-ARBITRAGE' <-
  c("//IRS990ScheduleK/Form990ScheduleKPartIV", "//IRS990ScheduleK/TaxExemptBondsArbitrageGrp"
  )

  TABLE.HEADERS$'SK-P05-T01-PROCEDURE-CORRECTIVE-ACT' <-
  c("//IRS990ScheduleK/FedTaxRequirementsCompliance", "//IRS990ScheduleK/Form990ScheduleKPartV",
  "//IRS990ScheduleK/ProceduresCorrectiveActionGrp")

  TABLE.HEADERS$'SK-P06-T99-SUPPLEMENTAL-INFO' <-
  c("//IRS990ScheduleK/Form990ScheduleKPartV", "//IRS990ScheduleK/Form990ScheduleKPartVI",
  "//IRS990ScheduleK/SupplementalInformationDetail")

  TABLE.HEADERS$'SL-P01-T01-EXCESS-BENEFIT-TRANSAC' <-
  c("//IRS990ScheduleL/DisqualifiedPersonExBnftTrGrp", "//IRS990ScheduleL/DQPTable",
  "//Form990ScheduleLPartI/DQPTable")

  TABLE.HEADERS$'SL-P02-T01-LOANS-INTERESTED-PERS' <-
  c("//Form990ScheduleLPartII/LoanTable", "//IRS990ScheduleL/LoansBtwnOrgInterestedPrsnGrp",
  "//IRS990ScheduleL/LoanTable")

  TABLE.HEADERS$'SL-P03-T01-GRANTS-INTERESTED-PERS' <-
  c("//IRS990ScheduleL/Form990ScheduleLPartIII", "//IRS990ScheduleL/GrntAsstBnftInterestedPrsnGrp"
  )

  TABLE.HEADERS$'SL-P04-T01-BIZ-TRANSAC-INTERESTED-PERS' <-
  c("//IRS990ScheduleL/BusTrInvolveInterestedPrsnGrp", "//IRS990ScheduleL/Form990ScheduleLPartIV"
  )

  TABLE.HEADERS$'SL-P05-T99-SUPPLEMENTAL-INFO' <-
  c("//IRS990ScheduleL/Form990ScheduleLPartV", "//IRS990ScheduleL/SupplementalInformationDetail"
  )

  TABLE.HEADERS$'SM-P01-T01-NONCASH-CONTRIBUTIONS' <-
  c("//Form990ScheduleMPartI/OtherNonCashContributionsTable", "//IRS990ScheduleM/OtherNonCashContributionsTable",
  "//IRS990ScheduleM/OtherNonCashContriTableGrp")

  TABLE.HEADERS$'SM-P02-T99-SUPPLEMENTAL-INFO' <-
  c("//IRS990ScheduleM/Form990ScheduleMPartII", "//IRS990ScheduleM/SupplementalInformationDetail"
  )

  TABLE.HEADERS$'SN-P01-T01-LIQUIDATION-TERMINATION-DISSOLUTION' <-
  c("//Form990ScheduleNPartI/LiquidationTable", "//LiquidationOfAssetsTableGrp/LiquidationOfAssetsDetail",
  "//IRS990ScheduleN/LiquidationTable")

  TABLE.HEADERS$'SN-P02-T01-DISPOSITION-OF-ASSETS' <-
  c("//IRS990ScheduleN/DispositionOfAssetsDetail", "//IRS990ScheduleN/DispositionTable",
  "//Form990ScheduleNPartII/DispositionTable")

  TABLE.HEADERS$'SN-P03-T99-SUPPLEMENTAL-INFO' <-
  c("//IRS990ScheduleN/ExplanatoryText", "//IRS990ScheduleN/Form990ScheduleNPartIII",
  "//IRS990ScheduleN/SupplementalInformationDetail")

  TABLE.HEADERS$'SO-T99-SUPPLEMENTAL-INFO' <-
  c("//IRS990ScheduleO/GeneralExplanation", "//IRS990ScheduleO/SupplementalInformationDetail"
  )

  TABLE.HEADERS$'SR-P01-T01-ID-DISREGARDED-ENTITIES' <-
  c("//IRS990ScheduleR/Form990ScheduleRPartI", "//IRS990ScheduleR/IdDisregardedEntitiesGrp"
  )

  TABLE.HEADERS$'SR-P02-T01-ID-RLTD-TAX-EXEMPED-ORGS' <-
  c("//IRS990ScheduleR/Form990ScheduleRPartII", "//IRS990ScheduleR/IdRelatedTaxExemptOrgGrp"
  )

  TABLE.HEADERS$'SR-P03-T01-ID-RLTD-ORGS-TAXABLE-PARTNERSHIP' <-
  c("//IRS990ScheduleR/Form990ScheduleRPartIII", "//IRS990ScheduleR/IdRelatedOrgTxblPartnershipGrp"
  )

  TABLE.HEADERS$'SR-P04-T01-ID-RLTD-ORGS-TAXABLE-CORPORATION' <-
  c("//IRS990ScheduleR/Form990ScheduleRPartIV", "//IRS990ScheduleR/IdRelatedOrgTxblCorpTrGrp"
  )

  TABLE.HEADERS$'SR-P05-T01-TRANSACTIONS-RLTD-ORGS' <-
  c("//Form990ScheduleRPartV/TransactionsRelatedOrgsTable", "//IRS990ScheduleR/TransactionsRelatedOrgGrp",
  "//IRS990ScheduleR/TransactionsRelatedOrgsTable")

  TABLE.HEADERS$'SR-P06-T01-UNRLTD-ORGS-TAXABLE-PARTNERSHIP' <-
  c("//IRS990ScheduleR/Form990ScheduleRPartVI", "//IRS990ScheduleR/UnrelatedOrgTxblPartnershipGrp"
  )

  TABLE.HEADERS$'SR-P07-T99-SUPPLEMENTAL-INFO' <-
  c("//IRS990ScheduleR/Form990ScheduleRPartVII", "//IRS990ScheduleR/SupplementalInformationDetail"
  )

  return( TABLE.HEADERS )

}

