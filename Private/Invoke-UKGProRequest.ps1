function Invoke-UKGProRequest {
    <#
    .SYNOPSIS
        Central REST wrapper for all UKG Pro API calls.

    .DESCRIPTION
        Every public cmdlet routes through here so authentication, pagination,
        and error handling live in one place.

        Responsibilities:
          - Verify there is an active session (Connect-UKGPro was called).
          - Attach the three required auth headers:
              Authorization: Basic <base64 user:pass>
              US-CUSTOMER-API-KEY: <customer api key>
              US-CLIENT-ID:        <primary company code>
          - Follow page/per_Page pagination automatically, aggregating results,
            with an optional -MaxResults cap.

        Unlike UKG HRSD (cursor headers), Pro uses page-number pagination: we
        request page 1, 2, 3... until a page returns fewer than per_Page rows.

    .NOTES
        Internal helper. Not exported.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Get', 'Post', 'Patch', 'Put', 'Delete')]
        [string]$Method,

        # Relative path under the base host, e.g. '/personnel/v1/employment-details'.
        [Parameter(Mandatory)]
        [string]$Path,

        # Query string parameters as a hashtable.
        [hashtable]$Query,

        # Request body (for later write cmdlets). Serialized to JSON.
        [object]$Body,

        # Rows per page to request. UKG applies a default max if unset.
        [int]$PageSize = 100,

        # Cap total records returned across all pages. 0 = no cap (all pages).
        [int]$MaxResults = 0,

        # When set, request only the first page (no auto-paging).
        [switch]$NoPaging
    )

    # --- 1. Ensure we have a live session -------------------------------------
    if (-not $script:UKGProSession) {
        throw "Not connected. Run Connect-UKGPro first."
    }

    # --- 2. Build auth headers ------------------------------------------------
    $headers = @{
        Authorization         = "Basic $($script:UKGProSession.BasicToken)"
        'US-CUSTOMER-API-KEY' = $script:UKGProSession.CustomerApiKey
        'US-CLIENT-ID'        = $script:UKGProSession.ClientId
        Accept                = 'application/json'
    }

    $baseUri = "$($script:UKGProSession.BaseUrl)$Path"

    # Copy incoming query params so we can add paging keys without mutating caller state.
    $q = @{}
    if ($Query) { foreach ($k in $Query.Keys) { $q[$k] = $Query[$k] } }

    $results  = [System.Collections.Generic.List[object]]::new()
    $page     = 1

    while ($true) {
        if (-not $NoPaging) {
            $q['page']     = $page
            $q['per_Page'] = $PageSize
        }

        # Assemble query string.
        $pairs = foreach ($key in $q.Keys) {
            $value = $q[$key]
            if ($null -eq $value) { continue }
            '{0}={1}' -f [uri]::EscapeDataString($key), [uri]::EscapeDataString([string]$value)
        }
        $uri = $baseUri
        if ($pairs) { $uri = "$baseUri`?$($pairs -join '&')" }

        $invokeParams = @{
            Method      = $Method
            Uri         = $uri
            Headers     = $headers
            ErrorAction = 'Stop'
        }
        if ($PSBoundParameters.ContainsKey('Body') -and $null -ne $Body) {
            $invokeParams.Body        = ($Body | ConvertTo-Json -Depth 20)
            $invokeParams.ContentType = 'application/json'
        }

        try {
            $response = Invoke-RestMethod @invokeParams
        }
        catch {
            throw (Get-UKGProErrorMessage -ErrorRecord $_)
        }

        # Normalize: Pro list endpoints return a JSON array of records.
        $batch = @($response)
        foreach ($item in $batch) { [void]$results.Add($item) }

        if ($NoPaging) { break }
        if ($MaxResults -gt 0 -and $results.Count -ge $MaxResults) { break }

        # Last page when we got fewer rows than we asked for (or none).
        if ($batch.Count -lt $PageSize) { break }

        $page++
    }

    if ($MaxResults -gt 0 -and $results.Count -gt $MaxResults) {
        return $results[0..($MaxResults - 1)]
    }
    return $results
}
