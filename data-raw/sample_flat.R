# data-raw/sample_flat.R
# Build inst/extdata/sample_flat.rds, the flattened copy of sample_990.xml that
# the "extract tables" and "updating the concordance" vignettes start from.
# Rerun it whenever flatten_xml() or get_table_id() changes its output.

devtools::load_all()

url <- "https://gt990datalake-rawdata.s3.amazonaws.com/EfileData/XmlFiles/202341529349301414_public.xml"
doc <- xml2::read_xml( "inst/extdata/sample_990.xml" )
xml2::xml_ns_strip( doc )

flat <- flatten_xml( doc, url )
saveRDS( flat, "inst/extdata/sample_flat.rds" )
