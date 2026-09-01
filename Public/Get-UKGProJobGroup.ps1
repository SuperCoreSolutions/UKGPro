function Get-UKGProJobGroup {
    <#
    .SYNOPSIS
        Retrieves UKG Pro job-group configuration rows (jobGroupCode -> description).

    .DESCRIPTION
        Wraps GET /configuration/v1/jobgroup. Job groups are the coarse-grained
        buckets that jobs roll up into (e.g. "Management", "Technical") and
        show up on employment records as jobGroupCode. This cmdlet resolves
        those codes to human-readable descriptions and supports the endpoint's
        native country filter.

        Requires only the "View" role on the "Company Configuration Integration"
        Web Service.

    .PARAMETER JobGroupCode
        Filter by a specific job group code (e.g. 'MGMT'). Server-side filter.

    .PARAMETER CountryCode
        Filter by country. Maps to the endpoint's `jobGroupCountryCode` query
        parameter. Server-side filter.

    .PARAMETER MaxResults
        Cap total records across all pages. `0` = no cap. Default: `0`.

    .PARAMETER PageSize
        Rows per page to request. Default: `100`.

    .EXAMPLE
        Get-UKGProJobGroup

        Return every job group in the tenant.

    .EXAMPLE
        (Get-UKGProJobGroup -JobGroupCode 'MGMT').jobGroupCodeDescription

        Resolve a specific job group code to its description — useful when you
        have a code from an employment record and want the display name.

    .EXAMPLE
        Get-UKGProJobGroup -CountryCode 'US'

        List every US job group.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter()] [string]$JobGroupCode,
        [Parameter()] [string]$CountryCode,

        [Parameter()] [int]$MaxResults = 0,
        [Parameter()] [int]$PageSize   = 100
    )

    $q = @{}
    if ($JobGroupCode) { $q['jobGroupCode']        = $JobGroupCode }
    if ($CountryCode)  { $q['jobGroupCountryCode'] = $CountryCode }

    Invoke-UKGProRequest -Method Get -Path '/configuration/v1/jobgroup' `
        -Query $q -PageSize $PageSize -MaxResults $MaxResults
}
