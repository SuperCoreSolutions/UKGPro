function Disconnect-UKGPro {
    <#
    .SYNOPSIS
        Clears the current UKG Pro session.

    .DESCRIPTION
        Removes the stored session (Basic token, API key, client id, base URL)
        from module state. UKG Pro uses stateless per-request auth, so there is
        no server-side token to revoke — this simply clears local credentials.

    .EXAMPLE
        Disconnect-UKGPro
    #>
    [CmdletBinding()]
    param ()

    if (-not $script:UKGProSession) {
        Write-Verbose "No active UKG Pro session to disconnect."
        return
    }

    $script:UKGProSession = $null
    Write-Verbose "UKG Pro session cleared."
}
