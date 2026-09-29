function Get-UKGProLocation {
    <#
    .SYNOPSIS
        Retrieves UKG Pro location configuration rows (locationCode -> full
        address / GL details).

    .DESCRIPTION
        Wraps GET /configuration/v1/locations (list) and
        GET /configuration/v1/locations/{code} (unique lookup), routing
        automatically based on which parameters are supplied. Location codes
        show up on employment records as `locationCode`; this cmdlet resolves
        them to a full location configuration including description, address,
        country, and the GL segment.

        Requires only the "View" role on the "Company Configuration Integration"
        Web Service.

        Note: the list endpoint doesn't accept `locationCode` as a query filter
        (only `countryCode` and `isActive`), so `-Code` is mutually exclusive
        with `-CountryCode` / `-IsActive` — enforced by parameter sets.

    .PARAMETER Code
        Location code. Hits the unique-lookup endpoint and returns a single
        location. Cannot be combined with `-CountryCode` / `-IsActive`.

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
        Get-UKGProLocation -Code 'HQ01'

        Unique lookup — return the single location with code `HQ01`.

    .EXAMPLE
        Get-UKGProLocation

        Every location in the tenant.

    .EXAMPLE
        Get-UKGProLocation -CountryCode 'US' -IsActive $true

        List every active US location.
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType([pscustomobject])]
    param (
        [Parameter(ParameterSetName = 'ByCode', Mandatory)]
        [string]$Code,

        [Parameter(ParameterSetName = 'List')]
        [string]$CountryCode,

        [Parameter(ParameterSetName = 'List')]
        [Nullable[bool]]$IsActive,

        [Parameter()] [int]$MaxResults = 0,
        [Parameter()] [int]$PageSize   = 100
    )

    # --- Unique lookup: -Code hits /locations/{code} directly ---
    if ($PSCmdlet.ParameterSetName -eq 'ByCode') {
        return Invoke-UKGProRequest -Method Get `
            -Path "/configuration/v1/locations/$Code" `
            -NoPaging |
            Add-UKGProTypeName -TypeName 'UKGPro.Location'
    }

    # --- Otherwise, list endpoint with any provided filters ---
    $q = @{}
    if ($CountryCode) { $q['countryCode'] = $CountryCode }
    if ($PSBoundParameters.ContainsKey('IsActive')) {
        # PowerShell's parameter binder unwraps [Nullable[bool]] to plain [bool];
        # serialize directly. Lowercase matches REST convention.
        $q['isActive'] = ([string]$IsActive).ToLower()
    }

    Invoke-UKGProRequest -Method Get -Path '/configuration/v1/locations' `
        -Query $q -PageSize $PageSize -MaxResults $MaxResults |
        Add-UKGProTypeName -TypeName 'UKGPro.Location'
}
