function Connect-UKGPro {
    <#
    .SYNOPSIS
        Establishes an authenticated session with the UKG Pro HCM API.

    .DESCRIPTION
        UKG Pro core REST APIs authenticate with THREE pieces sent on every call:
          - Basic auth: a service-account username/password, base64 encoded.
          - US-CUSTOMER-API-KEY: your tenant's Customer API Key
            (System Configuration > Security > Web Services > Customer API Key).
          - US-CLIENT-ID: your tenant's Primary Company Code
            (System Configuration > Company Setup > Primary Company Code).

        The base URL (hostname) is tenant-specific and assigned by UKG; find it
        under your Service Endpoint information (see
        https://developer.ukg.com/hcm/docs/web-service-account).

        This cmdlet validates and stores all of that in a module-private session
        so the Get-UKGPro* cmdlets can authenticate automatically. Credentials
        are never passed on individual calls.

    .PARAMETER Hostname
        Your tenant's service endpoint host, with or without https://. Examples:
        'servicet.ultipro.com', 'https://service5.ultipro.com'.

    .PARAMETER Credential
        A PSCredential for the UKG Pro service account (UserName = username,
        Password = password).

    .PARAMETER CustomerApiKey
        Your tenant's Customer API Key.

    .PARAMETER ClientId
        Your tenant's Primary Company Code (sent as US-CLIENT-ID).

    .PARAMETER PassThru
        Return the session object (secrets redacted) instead of nothing.

    .EXAMPLE
        $cred = Get-Credential   # service account username / password
        Connect-UKGPro -Hostname 'service5.ultipro.com' `
                       -Credential $cred `
                       -CustomerApiKey 'abc123...' `
                       -ClientId 'ACME'

    .EXAMPLE
        Connect-UKGPro -Hostname 'service5.ultipro.com' -Credential $cred `
                       -CustomerApiKey $key -ClientId 'ACME' -PassThru
    #>
    [CmdletBinding()]
    [OutputType([void], [pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [string]$Hostname,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter(Mandatory)]
        [string]$CustomerApiKey,

        [Parameter(Mandatory)]
        [string]$ClientId,

        [switch]$PassThru
    )

    # Normalize the host into a clean https base URL with no trailing slash.
    $h = $Hostname.Trim()
    $h = $h -replace '^https?://', ''
    $h = $h.TrimEnd('/')
    $baseUrl = "https://$h"

    # Pre-compute the Basic token once; store that rather than the raw password.
    $user = $Credential.UserName
    $pass = $Credential.GetNetworkCredential().Password
    $pair = "{0}:{1}" -f $user, $pass
    $basicToken = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pair))

    # Module-private (script scope) so the token doesn't leak into global state.
    $script:UKGProSession = [pscustomobject]@{
        BaseUrl        = $baseUrl
        Hostname       = $h
        Username       = $user
        BasicToken     = $basicToken
        CustomerApiKey = $CustomerApiKey
        ClientId       = $ClientId
        ConnectedAt    = Get-Date
    }

    Write-Verbose "UKG Pro session established for $baseUrl (client-id $ClientId)."

    if ($PassThru) {
        [pscustomobject]@{
            BaseUrl     = $script:UKGProSession.BaseUrl
            Username    = $script:UKGProSession.Username
            ClientId    = $script:UKGProSession.ClientId
            ConnectedAt = $script:UKGProSession.ConnectedAt
        }
    }
}
