function Get-UKGProJob {
    <#
    .SYNOPSIS
        Retrieves UKG Pro job configuration rows (jobCode -> full job details).

    .DESCRIPTION
        Wraps GET /configuration/v2/jobs (list) and
        GET /configuration/v2/jobs/{code} (unique lookup), routing automatically
        based on which parameters are supplied. Job codes show up as
        primaryJobCode on employment records; this cmdlet resolves them to a
        full job configuration including title, FLSA type, EEO category, job
        family, work environment, and a longer description.

        Uses UKG's v2 endpoints — UKG's own spec marks v1 as deprecated and v2
        has strictly more capability (jobCode as a server-side filter,
        pagination, richer response shape).

        Requires only the "View" role on the "Company Configuration Integration"
        Web Service.

    .PARAMETER Code
        Job code (e.g. 'SWENG'). Alone, hits the unique-lookup endpoint and
        returns a single job. Combined with other filters, is applied as a
        server-side `jobCode` filter on the list endpoint.

    .PARAMETER CountryCode
        Filter list by country code. Server-side filter.

    .PARAMETER IsActive
        Filter list by active/inactive status. Serialized as lowercase
        (`true` / `false`) in the URL.

    .PARAMETER MaxResults
        Cap total records across all pages. `0` = no cap. Default: `0`.

    .PARAMETER PageSize
        Rows per page to request. Default: `100`.

    .EXAMPLE
        Get-UKGProJob -Code 'SWENG'

        Unique lookup — return the single job with code `SWENG`.

    .EXAMPLE
        Get-UKGProJob -CountryCode 'US' -IsActive $true

        List every active US job.

    .EXAMPLE
        Get-UKGProJob | Select-Object jobCode, title, jobFamilyCode, flsaTypeCode

        Every job in the tenant, projected to the fields most useful for HR
        reporting.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter()] [string]$Code,
        [Parameter()] [string]$CountryCode,
        [Parameter()] [Nullable[bool]]$IsActive,

        [Parameter()] [int]$MaxResults = 0,
        [Parameter()] [int]$PageSize   = 100
    )

    $hasOtherFilters = $CountryCode -or $PSBoundParameters.ContainsKey('IsActive')

    # --- Unique lookup: -Code alone hits /jobs/{code} directly ---
    if ($Code -and -not $hasOtherFilters) {
        return Invoke-UKGProRequest -Method Get `
            -Path "/configuration/v2/jobs/$Code" `
            -NoPaging
    }

    # --- Otherwise, list endpoint with any provided filters ---
    $q = @{}
    if ($Code)        { $q['jobCode']     = $Code }
    if ($CountryCode) { $q['countryCode'] = $CountryCode }
    if ($PSBoundParameters.ContainsKey('IsActive')) {
        # PowerShell's parameter binder unwraps [Nullable[bool]] to plain [bool];
        # serialize directly. Lowercase matches REST convention.
        $q['isActive'] = ([string]$IsActive).ToLower()
    }

    Invoke-UKGProRequest -Method Get -Path '/configuration/v2/jobs' `
        -Query $q -PageSize $PageSize -MaxResults $MaxResults
}
