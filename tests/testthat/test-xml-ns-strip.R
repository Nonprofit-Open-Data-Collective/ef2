test_that("xml_ns_strip_fast() matches xml2::xml_ns_strip()", {
  docs <- c(
    '<Return xmlns="http://www.irs.gov/efile"><A><B>1</B></A></Return>',
    '<Return xmlns="http://a"><A xmlns="http://b"><B>1</B></A><C/></Return>',
    '<Return xmlns="http://a" xmlns:irs="http://i"><irs:A><B/></irs:A></Return>',
    '<Return xmlns="http://a"><A xmlns=""><B/></A><C xmlns="http://c"><D xmlns="http://d"/></C></Return>',
    '<Return><A xmlns="http://a"><B/></A><A xmlns="http://a"/></Return>',
    '<Return/>'
  )
  for (raw in docs) {
    a <- xml2::read_xml(raw); xml2::xml_ns_strip(a)
    b <- xml2::read_xml(raw); xml_ns_strip_fast(b)
    expect_identical(as.character(b), as.character(a))
    expect_identical(xml2::xml_path(xml2::xml_find_all(b, "//*")),
                     xml2::xml_path(xml2::xml_find_all(a, "//*")))
  }
})

test_that("get_xml_paths() matches xml2::xml_path()", {
  docs <- c(
    '<Return><A><B>1</B><B>2</B><C>x</C></A><A><B>3</B></A><D/></Return>',
    '<Return><A><A><A/></A></A><B><A/><A/></B><A/></Return>',
    '<Return/>'
  )
  for (raw in docs) {
    d <- xml2::read_xml(raw)
    expect_identical(get_xml_paths(d), xml2::xml_path(xml2::xml_find_all(d, "//*")))
  }
})

test_that("xml_prefix_strip() parses an irs:-prefixed return like a plain one (EF2-11)", {
  body <- paste0(
    '<ReturnHeader><ReturnTs>2024-06-13T19:00:48-07:00</ReturnTs>',
    '<TaxPeriodEndDt>2023-12-31</TaxPeriodEndDt><ReturnTypeCd>990PF</ReturnTypeCd>',
    '<TaxPeriodBeginDt>2023-01-01</TaxPeriodBeginDt>',
    '<Filer><EIN>834475806</EIN><BusinessName><BusinessNameLine1Txt>X</BusinessNameLine1Txt>',
    '</BusinessName></Filer><TaxYr>2023</TaxYr></ReturnHeader>',
    '<ReturnData><IRS990PF documentId="1"><A>1</A><A>2</A></IRS990PF></ReturnData>')
  ns <- 'xmlns="http://www.irs.gov/efile" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
  plain_txt  <- paste0('<Return returnVersion="2023v5.0" ', ns, '>', body, '</Return>')
  prefix_txt <- gsub("<(/?)([A-Za-z])", "<\\1irs:\\2", plain_txt)
  prefix_txt <- sub('xmlns="', 'xmlns:irs="http://www.irs.gov/efile" xmlns="', prefix_txt)
  expect_match(prefix_txt, "<irs:ReturnHeader>", fixed = TRUE)

  plain <- xml2::read_xml(plain_txt); xml_ns_strip_fast(plain)
  expect_identical(xml_prefix_strip(plain), plain)          # untouched, no re-parse

  pref <- xml2::read_xml(prefix_txt); xml_ns_strip_fast(pref)
  pref <- xml_prefix_strip(pref)
  expect_identical(get_xml_paths(pref), get_xml_paths(plain))
  expect_false(any(grepl("irs:", xml2::xml_path(xml2::xml_find_all(pref, "//*")))))
  k <- get_keys(pref, "https://x/202431769349100633_public.xml")
  expect_identical(k$RETURN_TYPE, "990PF")
  expect_identical(k$ORG_EIN, "834475806")
  expect_identical(k, get_keys(plain, "https://x/202431769349100633_public.xml"))
})
