function Get-UKGProCompanyDetails {
    <#
    .SYNOPSIS
        Retrieves UKG Pro company records — name, addresses, phone, federal
        tax ID, org-level codes for master and component companies.

    .DESCRIPTION
        Wraps GET /configuration/v1/company-details. Useful for multi-company
        tenants running per-company reports, resolving a companyId or
        companyCode from an employment record into a full company record, or
        listing every master company in the tenant.

        Requires only the "View" role on the "Company Configuration Integration"
        Web Service.

    .PARAMETER CompanyId
        Filter by 5-character UKG Pro HCM CompanyID. Server-side filter.

    .PARAMETER MasterCompanyId
        Filter by 5-character Master CompanyID. Server-side filter.

    .PARAMETER CompanyCode
        Filter by 5-character Company Code. Server-side filter.

    .PARAMETER IsMasterCompany
        Filter to master companies only (or component companies only if
        `$false`). Serialized as lowercase (`true` / `false`) in the URL.

    .PARAMETER MaxResults
        Cap total records across all pages. `0` = no cap. Default: `0`.

    .PARAMETER PageSize
        Rows per page to request. Default: `100`.

    .EXAMPLE
        Get-UKGProCompanyDetails

        Return every master and component company in the tenant.

    .EXAMPLE
        Get-UKGProCompanyDetails -CompanyId 'ACME'

        Resolve a specific companyId (from an employment record, for example)
        into the full company record.

    .EXAMPLE
        Get-UKGProCompanyDetails -IsMasterCompany $true

        List only master companies.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter()] [string]$CompanyId,
        [Parameter()] [string]$MasterCompanyId,
        [Parameter()] [string]$CompanyCode,
        [Parameter()] [Nullable[bool]]$IsMasterCompany,

        [Parameter()] [int]$MaxResults = 0,
        [Parameter()] [int]$PageSize   = 100
    )

    $q = @{}
    if ($CompanyId)       { $q['companyId']       = $CompanyId }
    if ($MasterCompanyId) { $q['masterCompanyId'] = $MasterCompanyId }
    if ($CompanyCode)     { $q['companyCode']     = $CompanyCode }
    if ($PSBoundParameters.ContainsKey('IsMasterCompany')) {
        # [Nullable[bool]] is unwrapped by the binder; serialize directly.
        $q['isMasterCompany'] = ([string]$IsMasterCompany).ToLower()
    }

    Invoke-UKGProRequest -Method Get -Path '/configuration/v1/company-details' `
        -Query $q -PageSize $PageSize -MaxResults $MaxResults
}
