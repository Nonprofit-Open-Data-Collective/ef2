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
