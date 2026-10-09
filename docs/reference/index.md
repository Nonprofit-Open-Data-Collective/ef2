# Package index

## The concordance

The master crosswalk mapping XML XPaths to standardized variable names
and relational tables, plus tools to refresh and validate it.

- [`get_concordance()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_concordance.md)
  : Retrieve the Concordance File
- [`prep_concordance()`](https://nonprofit-open-data-collective.github.io/ef2/reference/prep_concordance.md)
  : Prepare a concordance crosswalk (uppercase colnames)
- [`update_concordance()`](https://nonprofit-open-data-collective.github.io/ef2/reference/update_concordance.md)
  : Refresh the packaged concordance from GitHub
- [`concordance_is_current()`](https://nonprofit-open-data-collective.github.io/ef2/reference/concordance_is_current.md)
  : Check whether the packaged concordance is current
- [`release_concordance()`](https://nonprofit-open-data-collective.github.io/ef2/reference/release_concordance.md)
  : Concordance a published release was labelled with

## The filing index

Locate the returns available to process from the Giving Tuesday Data
Commons.

- [`get_current_index_full()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_current_index_full.md)
  : Load the full IRS 990 e-filer index from the Data Commons
- [`get_current_index_batch()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_current_index_batch.md)
  : Load the most recent IRS 990 e-filer batch index from the Data
  Commons
- [`find_current_index_full()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_current_index_full.md)
  : Find Most Recent AWS Full Index
- [`find_current_index_batch()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_current_index_batch.md)
  : Find Most Recent AWS Batch Index
- [`download_current_index_full()`](https://nonprofit-open-data-collective.github.io/ef2/reference/download_current_index_full.md)
  : Download Current AWS Index
- [`list_gt_indices()`](https://nonprofit-open-data-collective.github.io/ef2/reference/list_gt_indices.md)
  : List Index Files in the GTDC S3 Bucket

## Index helpers

Lower-level helpers used to resolve and validate index URLs.

- [`url_is_valid()`](https://nonprofit-open-data-collective.github.io/ef2/reference/url_is_valid.md)
  : Validate URL Status
- [`get_url_status()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_url_status.md)
  : Get URL Status
- [`get_url_status_df()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_url_status_df.md)
  : Get URL Status for Multiple Days
- [`get_last_n_dates()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_last_n_dates.md)
  : Get Last N Dates
- [`extract_dates()`](https://nonprofit-open-data-collective.github.io/ef2/reference/extract_dates.md)
  : Extract Dates from Filenames
- [`find_most_recent_date()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_most_recent_date.md)
  : Find Most Recent Date
- [`get_index_list_awscli()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_index_list_awscli.md)
  : Get AWS Index List
- [`extract_filenames_full()`](https://nonprofit-open-data-collective.github.io/ef2/reference/extract_filenames_full.md)
  : Extract Index Filenames
- [`extract_filenames_batch()`](https://nonprofit-open-data-collective.github.io/ef2/reference/extract_filenames_batch.md)
  : Extract Batch Index Filenames
- [`get_current_index_full_awscli()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_current_index_full_awscli.md)
  : Get Current AWS Index Using CLI
- [`get_all_batch_indices_awscli()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_all_batch_indices_awscli.md)
  : Get All Batch Index Filenames Using CLI

## Creating batch files

Split an index of URLs into batches for parallel processing.

- [`create_batchfiles()`](https://nonprofit-open-data-collective.github.io/ef2/reference/create_batchfiles.md)
  : Create batchfiles (RDS) for multiple years
- [`split_index()`](https://nonprofit-open-data-collective.github.io/ef2/reference/split_index.md)
  : Split index to batchfile RDS for a single year
- [`prep_index()`](https://nonprofit-open-data-collective.github.io/ef2/reference/prep_index.md)
  : Prepare an index for batching
- [`split_urls()`](https://nonprofit-open-data-collective.github.io/ef2/reference/split_urls.md)
  : Split a URL vector into named groups and persist RDS
- [`split_into_groups()`](https://nonprofit-open-data-collective.github.io/ef2/reference/split_into_groups.md)
  : Utility: split a vector into labeled groups
- [`write_batches()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_batches.md)
  : Write batch files to disk
- [`gather_batches()`](https://nonprofit-open-data-collective.github.io/ef2/reference/gather_batches.md)
  : Load pending batch files from disk
- [`remove_batch()`](https://nonprofit-open-data-collective.github.io/ef2/reference/remove_batch.md)
  : Remove a processed batch file

## Flattening XML

Convert one nested 990 XML filing into a long, one-row-per-node table.

- [`flatten_xml()`](https://nonprofit-open-data-collective.github.io/ef2/reference/flatten_xml.md)
  : Flatten an IRS 990 XML document to long-form rows
- [`get_flat_xml()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_flat_xml.md)
  : Download, parse, and flatten a single XML filing (with retries)
- [`batch_flatten()`](https://nonprofit-open-data-collective.github.io/ef2/reference/batch_flatten.md)
  : Flatten a batch of XML filings and write to DuckDB
- [`get_attr_df()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_attr_df.md)
  : Extract all XML node attributes into a tidy data frame
- [`get_keys()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_keys.md)
  : Get table keys for a single filing
- [`xml_ns_strip_fast()`](https://nonprofit-open-data-collective.github.io/ef2/reference/xml_ns_strip_fast.md)
  : Remove default namespaces from a document (fast xml_ns_strip)
- [`xml_prefix_strip()`](https://nonprofit-open-data-collective.github.io/ef2/reference/xml_prefix_strip.md)
  : Remove namespace prefixes from element names (EF2-11)
- [`get_xml_paths()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_xml_paths.md)
  : Xpaths of every element, in document order

## XML node & XPath helpers

Utilities used during flattening to classify nodes, derive table ids,
and read values from the XML tree.

- [`get_type()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_type.md)
  : Classify xpaths as parent or terminal
- [`find_parent_nodes()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_parent_nodes.md)
  : Find parent node xpaths for a set of xpaths
- [`find_terminal_nodes()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_terminal_nodes.md)
  : Find terminal node xpaths for a set of xpaths
- [`get_header()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_header.md)
  : Compute the TABLE_HEADER from an xpath
- [`get_table_id()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_table_id.md)
  : Make a TABLE_ID from a vector of xpaths
- [`get_n()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_n.md)
  : Extract the last bracketed index from an xpath
- [`get_vnames()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_vnames.md)
  : Vectorized variable name extraction from xpaths
- [`get_xpath_vname()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_xpath_vname.md)
  : Get the last node name from an xpath
- [`get_object_id()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_object_id.md)
  : Extract an OBJECTID from a filing URL
- [`get_object_id2()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_object_id2.md)
  : Extract an OBJECTID from a filing URL
- [`retrieve_xml()`](https://nonprofit-open-data-collective.github.io/ef2/reference/retrieve_xml.md)
  : Extract text from XML nodes
- [`standardize_boole()`](https://nonprofit-open-data-collective.github.io/ef2/reference/standardize_boole.md)
  : Standardize boolean inputs
- [`namedList()`](https://nonprofit-open-data-collective.github.io/ef2/reference/namedList.md)
  : Create a named list from its arguments

## Writing to DuckDB

Persist flattened filings into DuckDB tables.

- [`send_flat_xml_to_db()`](https://nonprofit-open-data-collective.github.io/ef2/reference/send_flat_xml_to_db.md)
  : Write flattened XML batch results to an existing DuckDB connection
- [`check_for_columns()`](https://nonprofit-open-data-collective.github.io/ef2/reference/check_for_columns.md)
  : Ensure destination DuckDB table has all required columns

## Building the database

Orchestrate parallel flattening of batches into a merged DuckDB
database.

- [`build_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_database.md)
  : Build a DuckDB database from batches of XML filings (parallel safe)
- [`resume_build_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/resume_build_database.md)
  : Resume a partial DuckDB build
- [`merge_duckdbs()`](https://nonprofit-open-data-collective.github.io/ef2/reference/merge_duckdbs.md)
  : Merge multiple worker DuckDB databases into a main database
- [`validate_merge()`](https://nonprofit-open-data-collective.github.io/ef2/reference/validate_merge.md)
  : Validate a merged DuckDB database against its worker sources
- [`dedupe_urls()`](https://nonprofit-open-data-collective.github.io/ef2/reference/dedupe_urls.md)
  : Drop repeated filings from a build list
- [`check_unique_keys()`](https://nonprofit-open-data-collective.github.io/ef2/reference/check_unique_keys.md)
  : Check that a built database holds each filing once

## Updating the database

Detect and process filings missing from an existing database.

- [`find_missing_urls()`](https://nonprofit-open-data-collective.github.io/ef2/reference/find_missing_urls.md)
  : Identify missing URLs in a given tax year
- [`update_db()`](https://nonprofit-open-data-collective.github.io/ef2/reference/update_db.md)
  : Update the DuckDB database for a given tax year
- [`merge_databases()`](https://nonprofit-open-data-collective.github.io/ef2/reference/merge_databases.md)
  : Merge DuckDB databases with schema alignment and timestamped logfile
- [`download_s3_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/download_s3_database.md)
  : Download an S3-hosted DuckDB archive to a local file
- [`append_to_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/append_to_database.md)
  : Append a temporary DuckDB (new filings) into an existing local
  DuckDB

## Connecting to DuckDB & S3

Open DuckDB connections and read/write databases on S3.

- [`open_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/open_database.md)
  : Open a DuckDB database connection with S3 support
- [`get_s3_database()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_s3_database.md)
  : Attach an S3-hosted DuckDB database by filename
- [`configure_aws_credentials()`](https://nonprofit-open-data-collective.github.io/ef2/reference/configure_aws_credentials.md)
  : Configure AWS credentials for DuckDB session
- [`write_csv_to_s3()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_csv_to_s3.md)
  : Write a DuckDB table to CSV on S3 via COPY
- [`s3_public_base()`](https://nonprofit-open-data-collective.github.io/ef2/reference/s3_public_base.md)
  : S3 prefix that built tables are published to

## Extracting tables

Pivot the flattened data into analysis-ready one-to-one and one-to-many
relational tables.

- [`extract_csv_tables()`](https://nonprofit-open-data-collective.github.io/ef2/reference/extract_csv_tables.md)
  : Extract All IRS 990 Tables from DuckDB Databases

- [`build_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_table.md)
  : Build a structured wide table and optionally export to CSV/S3

- [`build_rdb_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_rdb_table.md)
  : Build an RDB table from multiple header variants

- [`flatten_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/flatten_table.md)
  : Flatten a logical RDB table into wide format from FLATXML

- [`add_keys()`](https://nonprofit-open-data-collective.github.io/ef2/reference/add_keys.md)
  : Add KEYS columns to a flattened table

- [`get_table_names()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_table_names.md)
  : Get RDB table names from the concordance file

- [`get_table_headers()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_table_headers.md)
  : Get table headers

- [`audit_table_headers()`](https://nonprofit-open-data-collective.github.io/ef2/reference/audit_table_headers.md)
  : Audit TABLE.HEADERS for cross-table misfires

- [`add_exempt_type()`](https://nonprofit-open-data-collective.github.io/ef2/reference/add_exempt_type.md)
  :

  Add `F9_00_ORG_EXEMPT_TYPE` to the 990 header table

- [`write_table_output()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_table_output.md)
  : Write a built table to CSV and/or Parquet from a single DuckDB temp
  table

- [`verify_table_output()`](https://nonprofit-open-data-collective.github.io/ef2/reference/verify_table_output.md)
  : Verify that two serialisations of a table hold identical data

## Patch index

Find IRS filings missing from the GTDC index, re-host their XML, and
build a patch index to combine with it.

- [`get_irs_index()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_irs_index.md)
  : Read IRS e-file index files
- [`get_irs_zip_urls()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_irs_zip_urls.md)
  : List the IRS bulk-download zip files
- [`match_batch_zips()`](https://nonprofit-open-data-collective.github.io/ef2/reference/match_batch_zips.md)
  : Match IRS batch IDs to the zip files that hold them
- [`diff_irs_gt()`](https://nonprofit-open-data-collective.github.io/ef2/reference/diff_irs_gt.md)
  : Find IRS-indexed filings missing from the GTDC index
- [`fetch_irs_xml()`](https://nonprofit-open-data-collective.github.io/ef2/reference/fetch_irs_xml.md)
  : Extract missing filings from the IRS zip files
- [`read_return_headers()`](https://nonprofit-open-data-collective.github.io/ef2/reference/read_return_headers.md)
  : Read return-header fields from e-file XML documents
- [`build_patch_index()`](https://nonprofit-open-data-collective.github.io/ef2/reference/build_patch_index.md)
  : Build the patch index
- [`upload_patch()`](https://nonprofit-open-data-collective.github.io/ef2/reference/upload_patch.md)
  : Upload patch XML files and index to the NCCS bucket
- [`patch_url()`](https://nonprofit-open-data-collective.github.io/ef2/reference/patch_url.md)
  : Patch URL for a filing
- [`combine_index()`](https://nonprofit-open-data-collective.github.io/ef2/reference/combine_index.md)
  : Combine a GTDC index with a patch index

## Release notes

Compare two releases of the published tables and write release notes.

- [`compare_releases()`](https://nonprofit-open-data-collective.github.io/ef2/reference/compare_releases.md)
  : Compare two releases of the published tables
- [`write_release_notes()`](https://nonprofit-open-data-collective.github.io/ef2/reference/write_release_notes.md)
  : Write release notes from a release comparison
- [`condense_years()`](https://nonprofit-open-data-collective.github.io/ef2/reference/condense_years.md)
  : Collapse years into ranges

## Inspecting & reporting

Summarize database contents and report on XPath coverage across filings.

- [`inspect_ddb()`](https://nonprofit-open-data-collective.github.io/ef2/reference/inspect_ddb.md)
  : Inspect a DuckDB database interactively
- [`summarize_attr_table()`](https://nonprofit-open-data-collective.github.io/ef2/reference/summarize_attr_table.md)
  : Summarize attribute structure from a DuckDB database
- [`summarize_attr_schema()`](https://nonprofit-open-data-collective.github.io/ef2/reference/summarize_attr_schema.md)
  : Summarize the attribute schema from a tidy ATTRIBUTES table
- [`retrieve_attr_df()`](https://nonprofit-open-data-collective.github.io/ef2/reference/retrieve_attr_df.md)
  : Retrieve attribute data from a DuckDB database
- [`generate_xpath_report()`](https://nonprofit-open-data-collective.github.io/ef2/reference/generate_xpath_report.md)
  : Generate an XPATH Summary Report from a DuckDB Database
- [`process_xpaths()`](https://nonprofit-open-data-collective.github.io/ef2/reference/process_xpaths.md)
  : Combine and Process Multi-Year XPATH Reports

## Exploring table structure

Diagram the hierarchical structure of a table from its concordance
XPaths.

- [`get_table_xpaths()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_table_xpaths.md)
  : Get Table XPaths
- [`get_nd()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_nd.md)
  : Get Node Tree
- [`create_edgelist_v1()`](https://nonprofit-open-data-collective.github.io/ef2/reference/create_edgelist_v1.md)
  : Create Edgelist Version 1
- [`create_edgelist_v2()`](https://nonprofit-open-data-collective.github.io/ef2/reference/create_edgelist_v2.md)
  : Create Edgelist Version 2
- [`print_table_str()`](https://nonprofit-open-data-collective.github.io/ef2/reference/print_table_str.md)
  : Print Table Structure
- [`plot_table_str()`](https://nonprofit-open-data-collective.github.io/ef2/reference/plot_table_str.md)
  : Plot Table Structure

## Utilities

General-purpose helpers.

- [`format_ein()`](https://nonprofit-open-data-collective.github.io/ef2/reference/format_ein.md)
  : Format Employer Identification Numbers (EINs)
- [`extract_functions()`](https://nonprofit-open-data-collective.github.io/ef2/reference/extract_functions.md)
  : Extract Function Names and Arguments from an R Script
- [`generate_ascii_diagram()`](https://nonprofit-open-data-collective.github.io/ef2/reference/generate_ascii_diagram.md)
  : Generate an ASCII Diagram of Functions and Arguments from R Scripts

## Data

Datasets and data-structure references shipped with the package.

- [`concordance`](https://nonprofit-open-data-collective.github.io/ef2/reference/concordance.md)
  : Concordance of IRS e-file XPaths to standardized variables and
  tables
- [`index`](https://nonprofit-open-data-collective.github.io/ef2/reference/index-topic.md)
  : IRS 990 e-filer index (structure reference)
