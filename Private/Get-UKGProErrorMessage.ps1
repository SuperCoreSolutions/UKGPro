function Get-UKGProErrorMessage {
    <#
    .SYNOPSIS
        Turns a failed UKG Pro API call into a readable error string.

    .DESCRIPTION
        UKG Pro returns errors as JSON (application/problem+json or a plain
        object) on 500s, and bodyless responses on some 404/429s. This helper
        pulls the HTTP status and any response body out of the terminating error
        record and formats a single useful message, falling back to the raw
        exception when there's nothing parseable.

        429 (rate limited) is called out explicitly since Pro enforces it.

    .NOTES
        Internal helper. Not exported.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $status   = $null
    $bodyText = $null

    $response = $ErrorRecord.Exception.Response
    if ($response) {
        try { $status = [int]$response.StatusCode } catch { Write-Debug "Non-fatal: could not parse HTTP status code: $_" }

        if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
            $bodyText = $ErrorRecord.ErrorDetails.Message
        }
        elseif ($response.GetResponseStream) {
            try {
                $stream = $response.GetResponseStream()
                $reader = [System.IO.StreamReader]::new($stream)
                $bodyText = $reader.ReadToEnd()
                $reader.Dispose()
            }
            catch { Write-Debug "Ignored non-fatal failure while parsing error body: $_" }
        }
    }

    if ($status -eq 429) {
        return "UKG Pro API rate limit exceeded (HTTP 429). Slow down requests or reduce page size, then retry."
    }

    $detail = $null
    if ($bodyText) {
        try {
            $parsed = $bodyText | ConvertFrom-Json
            # problem+json uses 'title'/'detail'; other shapes may use 'message'.
            $detail = $parsed.detail
            if (-not $detail) { $detail = $parsed.title }
            if (-not $detail) { $detail = $parsed.message }
        }
        catch {
            $detail = $bodyText
        }
    }

    $prefix = if ($status) { "UKG Pro API error (HTTP $status)" } else { "UKG Pro API error" }
    if ($detail) { return "${prefix}: $detail" }
    return "${prefix}: $($ErrorRecord.Exception.Message)"
}
