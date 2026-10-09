# Get URL Status for Multiple Days

Checks the status of AWS index URLs for the last specified number of
days.

## Usage

``` r
get_url_status_df(days = 30)
```

## Arguments

- days:

  An integer specifying the number of days to check.

## Value

A data frame containing the status of URLs for each day.

## Examples

``` r
get_url_status_df(30)
#>                                                                                                                                  url
#> 1  https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-10-09.csv
#> 2  https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-10-08.csv
#> 3  https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-10-07.csv
#> 4  https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-10-06.csv
#> 5  https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-10-05.csv
#> 6  https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-10-04.csv
#> 7  https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-10-03.csv
#> 8  https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-10-02.csv
#> 9  https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-10-01.csv
#> 10 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-30.csv
#> 11 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-29.csv
#> 12 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-28.csv
#> 13 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-27.csv
#> 14 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-26.csv
#> 15 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-25.csv
#> 16 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-24.csv
#> 17 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-23.csv
#> 18 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-22.csv
#> 19 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-21.csv
#> 20 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-20.csv
#> 21 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-19.csv
#> 22 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-18.csv
#> 23 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-17.csv
#> 24 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-16.csv
#> 25 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-15.csv
#> 26 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-14.csv
#> 27 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-13.csv
#> 28 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-12.csv
#> 29 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-11.csv
#> 30 https://gt990datalake-rawdata.s3.us-east-1.amazonaws.com/Indices/990xmls/index_all_years_efiledata_xmls_created_on_2026-09-10.csv
#>    exists status
#> 1   FALSE    404
#> 2   FALSE    404
#> 3   FALSE    404
#> 4   FALSE    404
#> 5   FALSE    404
#> 6   FALSE    404
#> 7   FALSE    404
#> 8   FALSE    404
#> 9   FALSE    404
#> 10  FALSE    404
#> 11  FALSE    404
#> 12  FALSE    404
#> 13  FALSE    404
#> 14  FALSE    404
#> 15  FALSE    404
#> 16  FALSE    404
#> 17  FALSE    404
#> 18  FALSE    404
#> 19  FALSE    404
#> 20  FALSE    404
#> 21  FALSE    404
#> 22  FALSE    404
#> 23  FALSE    404
#> 24  FALSE    404
#> 25  FALSE    404
#> 26  FALSE    404
#> 27  FALSE    404
#> 28  FALSE    404
#> 29  FALSE    404
#> 30  FALSE    404
```
