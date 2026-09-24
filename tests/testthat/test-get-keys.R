make_return <- function(return_type, body) {
  xml <- sprintf(
    '<Return returnVersion="2023v5.0"><ReturnHeader>
       <ReturnTs>2024-05-01T10:00:00-05:00</ReturnTs>
       <TaxPeriodEndDt>2023-12-31</TaxPeriodEndDt>
       <ReturnTypeCd>%s</ReturnTypeCd>
       <TaxPeriodBeginDt>2023-01-01</TaxPeriodBeginDt>
       <Filer><EIN>012345678</EIN><BusinessName><BusinessNameLine1Txt>TEST ORG</BusinessNameLine1Txt></BusinessName></Filer>
       <TaxYr>2023</TaxYr>
     </ReturnHeader><ReturnData>%s</ReturnData></Return>', return_type, body)
  xml2::read_xml(xml)
}
url <- "https://gt990datalake-rawdata.s3.amazonaws.com/EfileData/XmlFiles/202400000000000001_public.xml"

test_that("get_keys reads the amended flag on 990-PF returns", {
  pf <- get_keys(make_return("990PF", "<IRS990PF><AmendedReturnInd>X</AmendedReturnInd></IRS990PF>"), url)
  expect_true(pf$RETURN_AMENDED_X)
  expect_identical(pf$RETURN_TYPE, "990PF")
  expect_false(pf$RETURN_GROUP_X)

  pf_old <- get_keys(make_return("990PF", "<IRS990PF><AmendedReturn>X</AmendedReturn></IRS990PF>"), url)
  expect_true(pf_old$RETURN_AMENDED_X)

  pf_orig <- get_keys(make_return("990PF", "<IRS990PF><InitialReturnInd>X</InitialReturnInd></IRS990PF>"), url)
  expect_false(pf_orig$RETURN_AMENDED_X)
})

test_that("get_keys still reads 990 and 990-EZ amended flags", {
  expect_true(get_keys(make_return("990", "<IRS990><AmendedReturnInd>X</AmendedReturnInd></IRS990>"), url)$RETURN_AMENDED_X)
  expect_true(get_keys(make_return("990EZ", "<IRS990EZ><AmendedReturnInd>X</AmendedReturnInd></IRS990EZ>"), url)$RETURN_AMENDED_X)
  expect_false(get_keys(make_return("990", "<IRS990><GroupReturnForAffiliatesInd>0</GroupReturnForAffiliatesInd></IRS990>"), url)$RETURN_AMENDED_X)
})

test_that("get_keys derives tax period length and the partial-year flag", {
  k <- get_keys(make_return("990PF", "<IRS990PF/>"), url)
  expect_identical(k$RETURN_TAXPER_DAYS, 365)
  expect_false(k$RETURN_PARTIAL_X)
  expect_identical(k$OBJECTID, "OID-202400000000000001")
})

test_that("get_keys reads the 501(c) subsection from its XML attribute", {
  # Current spelling, TY2013 onward.
  k990 <- get_keys(make_return(
    "990", '<IRS990><Organization501cInd organization501cTypeTxt="6">X</Organization501cInd></IRS990>'), url)
  expect_identical(k990$ORG_501C_SUBSECTION, "6")

  kez <- get_keys(make_return(
    "990EZ", '<IRS990EZ><Organization501cInd organization501cTypeTxt="4">X</Organization501cInd></IRS990EZ>'), url)
  expect_identical(kez$ORG_501C_SUBSECTION, "4")

  # Legacy spelling, TY2009-2012. Both must work or the panel breaks at 2013.
  k_old <- get_keys(make_return(
    "990", '<IRS990><Organization501c typeOf501cOrganization="19">X</Organization501c></IRS990>'), url)
  expect_identical(k_old$ORG_501C_SUBSECTION, "19")

  k_old_ez <- get_keys(make_return(
    "990EZ", '<IRS990EZ><Organization501c typeOf501cOrganization="7">X</Organization501c></IRS990EZ>'), url)
  expect_identical(k_old_ez$ORG_501C_SUBSECTION, "7")
})

test_that("get_keys returns NA for the subsection when it is absent", {
  # 501(c)(3) filers tick a different box and carry no subsection attribute.
  k3 <- get_keys(make_return(
    "990", "<IRS990><Organization501c3Ind>X</Organization501c3Ind></IRS990>"), url)
  expect_true(is.na(k3$ORG_501C_SUBSECTION))

  # 990-PF has no 501(c) subsection at all.
  expect_true(is.na(get_keys(make_return("990PF", "<IRS990PF/>"), url)$ORG_501C_SUBSECTION))

  # Element present but attribute missing.
  k_bare <- get_keys(make_return(
    "990", "<IRS990><Organization501cInd>X</Organization501cInd></IRS990>"), url)
  expect_true(is.na(k_bare$ORG_501C_SUBSECTION))
})

test_that("ORG_501C_SUBSECTION sits in the key list without disturbing the others", {
  k <- get_keys(make_return(
    "990", '<IRS990><Organization501cInd organization501cTypeTxt="12">X</Organization501cInd></IRS990>'), url)
  expect_true("ORG_501C_SUBSECTION" %in% names(k))
  expect_length(k, 17L)
  expect_identical(k$ORG_EIN, "012345678")
  expect_identical(k$TAX_YEAR, "2023")
  expect_identical(k$RETURN_TYPE, "990")
})
