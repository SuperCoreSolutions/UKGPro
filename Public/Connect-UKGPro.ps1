function Connect-UKGPro {
    <#
    .SYNOPSIS
        Establishes an authenticated session with the UKG Pro HCM API.

    .DESCRIPTION
        UKG Pro core REST APIs authenticate with THREE pieces sent on every call:
          - Basic auth: a web-service-account username/password, base64 encoded.
          - US-Customer-API-Key: your tenant's Customer API Key
            (System Configuration > Security > Web Services > Customer API Key).
          - x-api-key: the User API Key generated for the same web service account
            (shown alongside the account username in Web Services).

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
        A PSCredential for the UKG Pro web service account (UserName = username,
        Password = password).

    .PARAMETER CustomerApiKey
        Your tenant's Customer API Key (sent as US-Customer-API-Key).

    .PARAMETER UserApiKey
        The User API Key from the web service account (sent as x-api-key).

    .PARAMETER PassThru
        Return the session object (secrets redacted) instead of nothing.

    .EXAMPLE
        $cred = Get-Credential   # service account username / password
        Connect-UKGPro -Hostname 'service5.ultipro.com' `
                       -Credential $cred `
                       -CustomerApiKey 'abc123...' `
                       -UserApiKey 'def456...'

    .EXAMPLE
        Connect-UKGPro -Hostname 'service5.ultipro.com' -Credential $cred `
                       -CustomerApiKey $custKey -UserApiKey $userKey -PassThru
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
        [string]$UserApiKey,

        [switch]$PassThru
    )

    # Normalize the host into a clean https base URL with no trailing slash.
    $h = $Hostname.Trim()
    $h = $h -replace '^https?://', ''
    $h = $h.TrimEnd('/')
    $baseUrl = "https://$h"

    # Pre-compute the Basic token once; store that rather than the raw password.
    # ASCII matches what UKG's own examples use; service-account credentials
    # are ASCII in practice, so this is equivalent to UTF-8 for any real input
    # and avoids surprises if a byte-for-byte comparison ever comes up.
    $user = $Credential.UserName
    $pass = $Credential.GetNetworkCredential().Password
    $pair = "{0}:{1}" -f $user, $pass
    $basicToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

    # Module-private (script scope) so the token doesn't leak into global state.
    $script:UKGProSession = [pscustomobject]@{
        BaseUrl        = $baseUrl
        Hostname       = $h
        Username       = $user
        BasicToken     = $basicToken
        CustomerApiKey = $CustomerApiKey
        UserApiKey     = $UserApiKey
        ConnectedAt    = Get-Date
    }

    Write-Verbose "UKG Pro session established for $baseUrl (user $user)."

    if ($PassThru) {
        # UserApiKey is a secret and is deliberately omitted here.
        [pscustomobject]@{
            BaseUrl     = $script:UKGProSession.BaseUrl
            Username    = $script:UKGProSession.Username
            ConnectedAt = $script:UKGProSession.ConnectedAt
        }
    }
}
