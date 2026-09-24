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
