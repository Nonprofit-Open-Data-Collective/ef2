# Concordance of IRS e-file XPaths to standardized variables and tables

A curated crosswalk used by ef2 to normalize XML element paths (XPaths)
into consistent variable names (`variable_name`) and logical table
assignments (`rdb_table`). It also includes labeling, versioning, and
schema hints to support stable flattening across IRS schema versions.

## Usage

``` r
data(concordance)
```

## Format

A data frame with the following columns:

- xpath:

  Character. Unique XPaths derived from the IRS 990 e-file schema.

- variable_name:

  Character. Standardized variable name used in outputs.

- rdb_relationship:

  Character. Cardinality of tables (e.g., "ONE" for one-to-one).

- rdb_table:

  Character. Logical table label (variables grouped by form
  parts/sections).

- label:

  Character. Short human-readable label.

- description:

  Character. Longer description of the field meaning.

- location_code_xsd:

  Character. XSD-level location code (may be empty).

- location_code_family:

  Character. Location family on the 990 form (e.g.,
  "F990-PC-PART-00-LINE-00").

- location_code:

  Character. Specific location on the form; for 990 this may match the
  family.

- form:

  Character. IRS form, e.g., "F990", "F990EZ", "F990PF".

- form_type:

  Character. Form subtype, e.g., "PC" for full 990; "EZ" for 990EZ; "HD"
  for header.

- form_part:

  Character. Part identifier, e.g., "PART-00".

- form_line_number:

  Character. Line identifier, e.g., "Line 00".

- variable_scope:

  Character. Scope of variable (e.g., "HD" for header).

- data_type_xsd:

  Character. Raw XSD type (e.g., "TimestampType", "StringType").

- data_type_simple:

  Character. Simplified type such as "numeric", "text", "checkbox",
  "factor", "date".

- required:

  Logical or character. Whether the field is required (may be NA).

- versions:

  Character. Semicolon-separated schema versions where this mapping
  applies (e.g., "2013v3.0;2014v5.0;2015v2.0").

- latest_version:

  Integer or numeric or NA. Latest applicable version year if tracked.

- duplicated:

  Logical or character. Whether this mapping duplicates another row for
  compatibility.

- current_version:

  Logical or character. Marks mappings considered current/active.

- production_rule:

  Character or NA. Optional rule hints for production pipelines.

- validated:

  Character or NA. Optional validation flag or comments.

## Source

Nonprofit-Open-Data-Collective: IRS e-file master concordance file.
<https://github.com/Nonprofit-Open-Data-Collective/irs-efile-master-concordance-file>

## Details

Columns are kept as character where feasible (including booleans and
version lists) to avoid lossy coercions; downstream code may cast types
as needed for analytics. The dataset is refreshed from the public source
when you run `data-raw/concordance.R`.

## Examples

``` r
data(concordance)
head(concordance)
#>                                                xpath           variable_name
#>                                               <char>                  <char>
#> 1:                      /Return/ReturnHeader/BuildTS  F9_00_BUILD_TIME_STAMP
#> 2: /Return/ReturnHeader/Filer/BusinessNameControlTxt     F9_00_NAME_ORG_CTRL
#> 3:            /Return/ReturnHeader/Filer/NameControl     F9_00_NAME_ORG_CTRL
#> 4:                     /Return/ReturnHeader/ReturnTs F9_00_RETURN_TIME_STAMP
#> 5:                    /Return/ReturnHeader/Timestamp F9_00_RETURN_TIME_STAMP
#> 6:                   /Return/ReturnHeader/ReturnType       F9_00_RETURN_TYPE
#>    rdb_relationship         rdb_table             label
#>              <char>            <char>            <char>
#> 1:              ONE F9-P00-T00-HEADER  Build time stamp
#> 2:              ONE F9-P00-T00-HEADER Organization name
#> 3:              ONE F9-P00-T00-HEADER Organization name
#> 4:              ONE F9-P00-T00-HEADER Return time stamp
#> 5:              ONE F9-P00-T00-HEADER Return time stamp
#> 6:              ONE F9-P00-T00-HEADER       Return type
#>                                      description location_code_xsd
#>                                           <char>            <char>
#> 1:         Build time stamp - IRS internal field                  
#> 2:    Name of Filing Organization (Control Text)                  
#> 3:    Name of Filing Organization (Control Text)                  
#> 4: The date and time when the return was created                  
#> 5: The date and time when the return was created                  
#> 6:                                   Return type                  
#>       location_code_family           location_code   form form_type form_part
#>                     <char>                  <char> <char>    <char>    <char>
#> 1: F990-PC-PART-00-LINE-00 F990-PC-PART-00-LINE-00   F990        PC   PART-00
#> 2: F990-PC-PART-00-LINE-00 F990-PC-PART-00-LINE-00   F990        PC   PART-00
#> 3: F990-PC-PART-00-LINE-00 F990-PC-PART-00-LINE-00   F990        PC   PART-00
#> 4: F990-PC-PART-00-LINE-00 F990-PC-PART-00-LINE-00   F990        PC   PART-00
#> 5: F990-PC-PART-00-LINE-00 F990-PC-PART-00-LINE-00   F990        PC   PART-00
#> 6: F990-PC-PART-00-LINE-00 F990-PC-PART-00-LINE-00   F990        PC   PART-00
#>    form_line_number variable_scope           data_type_xsd data_type_simple
#>              <char>         <char>                  <char>           <char>
#> 1:          Line 00             HD                                     date
#> 2:          Line 00             HD BusinessNameControlType             text
#> 3:          Line 00             HD BusinessNameControlType             text
#> 4:          Line 00             HD           TimestampType             date
#> 5:          Line 00             HD           TimestampType             date
#> 6:          Line 00             HD              StringType             text
#>    required
#>      <lgcl>
#> 1:       NA
#> 2:    FALSE
#> 3:    FALSE
#> 4:       NA
#> 5:       NA
#> 6:       NA
#>                                                                                                                                                                      versions
#>                                                                                                                                                                        <char>
#> 1:                                                                                                                                                                           
#> 2:                                                                                           2013v3.0;2013v3.1;2013v4.0;2014v5.0;2014v6.0;2015v2.0;2015v2.1;2015v3.0;2016v3.0
#> 3: 2009v1.0;2009v1.1;2009v1.2;2009v1.3;2009v1.4;2009v1.7;2010v3.2;2010v3.4;2010v3.6;2010v3.7;2011v1.2;2011v1.3;2011v1.4;2011v1.5;2012v2.0;2012v2.1;2012v2.2;2012v2.3;2012v3.0
#> 4:                                                                                           2013v3.0;2013v3.1;2013v4.0;2014v5.0;2014v6.0;2015v2.0;2015v2.1;2015v3.0;2016v3.0
#> 5: 2009v1.0;2009v1.1;2009v1.2;2009v1.3;2009v1.4;2009v1.7;2010v3.2;2010v3.4;2010v3.6;2010v3.7;2011v1.2;2011v1.3;2011v1.4;2011v1.5;2012v2.0;2012v2.1;2012v2.2;2012v2.3;2012v3.0
#> 6: 2009v1.0;2009v1.1;2009v1.2;2009v1.3;2009v1.4;2009v1.7;2010v3.2;2010v3.4;2010v3.6;2010v3.7;2011v1.2;2011v1.3;2011v1.4;2011v1.5;2012v2.0;2012v2.1;2012v2.2;2012v2.3;2012v3.0
#>    latest_version duplicated current_version production_rule validated
#>             <int>     <lgcl>          <lgcl>          <char>    <char>
#> 1:             NA         NA              NA            <NA>      <NA>
#> 2:           2016      FALSE            TRUE            <NA>      <NA>
#> 3:           2012      FALSE            TRUE            <NA>      <NA>
#> 4:           2016      FALSE            TRUE            <NA>      <NA>
#> 5:           2012      FALSE            TRUE            <NA>      <NA>
#> 6:           2012      FALSE            TRUE            <NA>      <NA>
```
