# IRS 990 e-filer index (structure reference)

Describes the columns of the IRS 990 e-filer index returned by
[`get_current_index_full()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_current_index_full.md)
and
[`get_current_index_batch()`](https://nonprofit-open-data-collective.github.io/ef2/reference/get_current_index_batch.md).
This is a documentation-only reference for the index structure; the
index is downloaded on demand from the Giving Tuesday Data Commons
rather than shipped as package data.

## Format

A data frame with 35 variables:

- BuildTs:

  POSIXct: Timestamp indicating when the data was built.

- DAF:

  Logical: Indicates if the record relates to a Donor-Advised Fund.

- DateSigned:

  Date: The date the filing was signed.

- DocStatus:

  Character: Status of the filing document (e.g., approved, pending).

- EIN:

  Integer: Employer Identification Number of the organization.

- FileSha256:

  Character: SHA-256 checksum of the file for integrity verification.

- FileSizeBytes:

  Integer: Size of the file in bytes.

- FormType:

  Character: Type of IRS Form 990 (e.g., "990", "990EZ").

- GrossReceipts:

  Integer64: Gross receipts reported by the organization.

- GroupAffiliatesIncluded:

  Logical: Indicates if group affiliates are included.

- GroupExemptionNumber:

  Integer: Group exemption number if applicable.

- GroupReturnForAffiliates:

  Logical: Indicates if the return is for group affiliates.

- IndexedOn:

  Date: The date when the record was indexed.

- LegalDomicileCountry:

  Character: Country of legal domicile of the organization.

- LegalDomicileState:

  Character: State of legal domicile of the organization.

- ObjectId:

  Integer64: Unique identifier for the object.

- OrgType:

  Character: Type of organization (e.g., "Corp", "Association").

- OrganizationName:

  Character: Name of the organization.

- ReturnTs:

  POSIXct: Timestamp indicating when the return was submitted.

- ReturnVersion:

  Character: Version of the IRS form used.

- SubmittedOn:

  Date: Date when the return was submitted.

- TaxPeriod:

  Date: Tax period associated with the filing.

- TaxPeriodBeginDate:

  Date: Start date of the tax period.

- TaxPeriodEndDate:

  Date: End date of the tax period.

- TaxStatus:

  Character: Tax status of the organization (e.g., "501c3").

- TaxYear:

  Integer: The tax year the filing corresponds to.

- TotalAssetsBkEOY:

  Integer64: Total assets at the end of the year as per the
  organization's books.

- TotalExpensesCY:

  Integer64: Total expenses for the current year.

- TotalLiabilitiesBkEOY:

  Integer64: Total liabilities at the end of the year as per the
  organization's books.

- TotalNetAssetsBkEOY:

  Integer64: Total net assets at the end of the year as per the
  organization's books.

- TotalRevenueCY:

  Integer64: Total revenue for the current year.

- URL:

  Character: URL to the raw XML file of the IRS 990 data.

- Website:

  Character: Website of the organization.

- YearFormed:

  Integer: The year the organization was formed.

- ZipFile:

  Character: Name of the ZIP file if applicable.

## Source

Giving Tuesday: <https://990data.givingtuesday.org/>

## Examples

``` r
if (FALSE) { # \dontrun{
index <- get_current_index_full()
table(index$FormType,index$TaxYear) |> knitr::kable()
} # }
```
