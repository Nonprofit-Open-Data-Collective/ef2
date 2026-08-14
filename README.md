# ef2

Updated R package for processing IRS 990 Efile datasets. 

This package is a Gen 2 version of the [irs990efile](https://github.com/Nonprofit-Open-Data-Collective/irs990efile) package with an improved XML to RDB workflow that is more robust and reduces processing time to about 15 minutes per tax year (the original package takes about 3 days to process one tax year). 

Processed files are available on the NCCS website in CSV format: https://nccs.urban.org/nccs/datasets/efile/

The ef2 output tables work seamlessly with **panel990**, **fiscal**, **governance**, and other packages in the NODC ecosystem.

```r
# pak::pkg_install("nonprofit-open-data-collective/panel990")
library(panel990)    # build a panel

# 1. Download -> read -> merge -> stack five core tables across four years.
#    Filing keys (EIN2 / TAX_YEAR / OBJECTID) are assigned automatically;
#    bmf = TRUE attaches NCCS Business Master File organization traits.
panel <- panelize(
  tables = c("P00", "P01", "P08", "P09", "P10"),
  years  = 2019:2022,
  bmf    = TRUE
)

# 2. See who enters, exits, persists, and where the gaps are.
panel_describe(panel)

# 3. Clean the panel. Every step is logged into the sample frame.
panel <- panel |>
  panel_deduplicate() |>                          # one filing per org-year
  panel_normalize()  |>                           # blank core financials -> 0
  panel_impute(max_gap_size = 1) |>               # fill single-year gaps
  panel_smooth(vars = "F9_08_REV_TOT_TOT", window = 3)

# 4. Pull the tidy data frame and the provenance ledger.
df <- as.data.frame(panel)
manifest(panel)          # every step: rows in/out, rules applied
```

Add ~50 financial indicators to your panel: 

```r
# pak::pkg_install("nonprofit-open-data-collective/fiscal")
library(fiscal)

# The entire battery of fiscal-health metrics, appended to your data:
ratios <- compute_all( df )    

# ...or a single metric (adds debt_assets + _w / _z / _p):
df <- get_debt_assets_ratio( df )
```

## Installation

```r
# ef2 currently depends on these packages only available on github
pak::pkg_install( 'ultinomics/xmltools' )
pak::pkg_install( 'nonprofit-open-data-collective/ef2' )
```

## Usage

The efficiency gains from the package partly come from the pre-processing files. All XML files are converted into something similar to parquet (long) formats with one row per xpath within a document. These are stored in a Duck Database file. 

The desired tables are then extracted from the database using: 

```r
library( ef2 )

wd <- # project working directory
years <- 2020:2022
table_names <- c("F9-P08-T00-REVENUE","F9-P09-T00-EXPENSES","F9-P10-T00-BALANCE-SHEET")
extract_csv_tables( wd=wd, years=years, table_names=table_names )
```

The processed DuckDB databases are available at:  `https://nccs-efile.s3.dualstack.us-east-1.amazonaws.com/duckdb/efile_v2_1/` + EFILE{YEAR}.duckdb

You can attach S3 versions of DuckDB databases using virtual memory in order to execute processes without downloading the files to your local machine.

```r
version <- "efile_v2_1"
con <- get_s3_database( filename="EFILE2021.duckdb", version=version )
```

You can then run queries to inspect raw data or extract tables directly from S3.

```r
index <- get_current_index_full()
i2 <- dplyr::filter( index, FormType %in% c("990","990EZ") )
table( i2$TaxYear, i2$FormType ) |> knitr::kable()
```

|     |    990|  990EZ|
|:----|------:|------:|
|2007 |     17|     17|
|2008 |     87|    114|
|2009 |  33311|  15470|
|2010 | 123025|  63326|
|2011 | 159504|  82048|
|2012 | 179688|  93750|
|2013 | 198855| 104375|
|2014 | 218619| 116417|
|2015 | 233519| 124894|
|2016 | 243903| 130484|
|2017 | 261612| 139145|
|2018 | 271442| 149384|
|2019 | 284515| 152689|
|2020 | 343790| 171891|
|2021 | 336521| 202730|
|2022 | 348034| 205532|
|2023 | 329042| 198731|
|2024 |  78817|  80682|


```r
# SPLIT INTO YEARS TO KEEP SIZE MANAGEABLE
dir.create("index")
for( i in 2009:2024 ){
  index_i <- dplyr::filter( i2, TaxYear == i )
  saveRDS( index_i, paste0("index/index",i,".rds") )
}
```

To build a new database: 

```r
YEAR <- "2020"
index_y <- readRDS( paste0( "index/index", YEAR, ".rds" ) )
build_database( year=YEAR, urls = index_y$URL )
```

You can update an existing database by differencing the XML files currently indexed in the database (using XPATH URL as the unique keys) and 

```r
update_db( year=YEAR, index = index_y )
```

It will only create database tables for the XML documents that are missing from the current database by checking for missing cases: 

```r
missing_urls <- find_missing_urls( year=YEAR, index = index_y )
```

Thus it is a more efficient way to maintain a database by updating the current version rather than building from scratch. 


## Process

### Step 1: Flatten XML Files 

Convert XML files to something the resembles a Parquet long format. Raw XML fields: 

```
<BooksInCareOfDetail>
  <PersonNm>Vanuel Bloss</PersonNm>
  <USAddress>
    <AddressLine1Txt>319 Linsbury Ct</AddressLine1Txt>
    <CityNm>Gastonia</CityNm>
    <StateAbbreviationCd>NC</StateAbbreviationCd>
    <ZIPCd>28056</ZIPCd>
  </USAddress>
  <PhoneNum>7048241662</PhoneNum>
</BooksInCareOfDetail>
```

Get converted into a table with one row per XML node. In other words, the file is flattened so that each piece of data (the VALUE column) gets a separate row. 


| XPATH                                             | NODE_TYPE | VARIABLE_NAME               | TABLE_NAME        | VALUE             |
|:------------------------------------------------- |:--------- |:--------------------------- |:----------------- |:----------------- |
| BooksInCareOfDetail                               | parent    |                             |                   |                   |
| BooksInCareOfDetail/PersonNm                      | terminal  | F9_P0_IN_CARE_OF_NAME       | F9-P00-T00-HEADER | Manuel Floss      |
| BooksInCareOfDetail/USAddress/AddressLine1Txt     | terminal  | F9_P0_IN_CARE_OF_ADDR_L1    | F9-P00-T00-HEADER | 319 Lingenbury Ct |
| BooksInCareOfDetail/USAddress/CityNm              | terminal  | F9_P0_IN_CARE_OF_ADDR_CITY  | F9-P00-T00-HEADER | Gastanio          |
| BooksInCareOfDetail/USAddress/StateAbbreviationCd | terminal  | F9_P0_IN_CARE_OF_ADDR_STATE | F9-P00-T00-HEADER | NC                |
| BooksInCareOfDetail/USAddress/ZIPCd               | terminal  | F9_P0_IN_CARE_OF_ADDR_ZIP   | F9-P00-T00-HEADER | 20056             |
| BooksInCareOfDetail/PhoneNum                      | terminal  | F9_P0_IN_CARE_OF_PHONE      | F9-P00-T00-HEADER | 8048241362        |

Note that some XML nodes are "parent" nodes whose only role is to group children nodes ("terminal" nodes) to provide the heirarchical structure that gives XML the flexibility to embed tables within tables. These nodes contain no data and filtered out before converting the flattened XML file into tables. 

Flattened XML files are stored as a DuckDB instance on an AWS S3 server. 

### Step 2: Extract Tables

The table structures and variable names are all defined within the [990 Concordance]() file. Once the XML conversions to flat files is complete, the data is transformed by pivoting each table to a "wide" format: 

**F9-P00-T00-HEADER TABLE**: 

| F9_P0_IN_CARE_OF_NAME | F9_P0_IN_CARE_OF_ADDR_L1 | F9_P0_IN_CARE_OF_ADDR_CITY | F9_P0_IN_CARE_OF_ADDR_STATE | F9_P0_IN_CARE_OF_ADDR_ZIP | F9_P0_IN_CARE_OF_PHONE |
| --------------------- | ------------------------ | -------------------------- | --------------------------- | ------------------------- | ---------------------- |
| Manuel Floss          | 319 Lingenbury Ct        | Gastanio                   | NC                          | 20056                     | 8048241362             |

### Additional Details 

All Efile tables contain a consistent set of metadata fields the describe both the organization (EIN, name), the type of filing (form type, tax year), and XML attributes (the original xpath, the URL of the raw file, the time stamp of return submission). 

In addition, they contain a set of filtering variables that are useful when preparing data for analysis - indicators of whether the filing in an amended return or a group return, and an indicator of whether it is a partial return. These fields are used for removing redundant files since 

## Code Tutorial 

### Step 1: Flatten XMLs

### Step 2: Attach an S3 DuckDB File 

### Step 3: Extract One-to-One Tables 

### Step 4: Extract One-to-Many Tables 






