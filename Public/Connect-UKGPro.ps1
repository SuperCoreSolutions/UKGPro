function Connect-UKGPro {
    <#
    .SYNOPSIS
        Establishes an authenticated session with the UKG Pro HCM API. Supports
        three input flows: explicit parameters, a saved SecretManagement vault,
        or environment variables.

    .DESCRIPTION
        UKG Pro core REST APIs authenticate with THREE pieces sent on every call:
          - Basic auth: a web-service-account username/password, base64 encoded.
          - US-Customer-API-Key: your tenant's Customer API Key.
          - x-api-key: the User API Key generated for the same web service account.

        The base URL (hostname) is tenant-specific and assigned by UKG; find it
        under your Service Endpoint information (see
        https://developer.ukg.com/hcm/docs/web-service-account).

        Three ways to supply these values:

        1. -Explicit (default) — pass everything as parameters.
        2. -FromVault — pull hostname + two API keys from a Microsoft
           SecretManagement vault; prompt (or accept -Credential) for the
           web-service-account username/password. Requires the module to have
           been set up once with Save-UKGProCredential.
        3. -FromEnvironment — read all five values from env vars, for
           fully non-interactive scenarios (CI runners, scheduled tasks,
           containers). Env vars: UKGPRO_HOSTNAME, UKGPRO_USERNAME,
           UKGPRO_PASSWORD, UKGPRO_CUSTOMER_API_KEY, UKGPRO_USER_API_KEY.

        This cmdlet validates and stores all of that in a module-private session
        so the Get-UKGPro* cmdlets can authenticate automatically. Credentials
        are never passed on individual calls.

    .PARAMETER Hostname
        Your tenant's service endpoint host, with or without https://. Examples:
        'servicet.ultipro.com', 'https://service5.ultipro.com'.

    .PARAMETER Credential
        A PSCredential for the UKG Pro web service account (UserName = username,
        Password = password). Mandatory in the Explicit parameter set. Optional
        in the FromVault set — if omitted, the cmdlet calls Get-Credential
        to prompt.

    .PARAMETER CustomerApiKey
        Your tenant's Customer API Key (sent as US-Customer-API-Key).

    .PARAMETER UserApiKey
        The User API Key from the web service account (sent as x-api-key).

    .PARAMETER FromVault
        Pull hostname + two API keys from a SecretManagement vault (populated
        by Save-UKGProCredential). Prompts for the web-service-account
        username/password via Get-Credential unless -Credential is supplied.

    .PARAMETER VaultName
        Optional. Name of a specific SecretManagement vault to read from.
        Omit to use the current default vault.

    .PARAMETER FromEnvironment
        Read all five values from environment variables. Intended for CI /
        scheduled task / container scenarios. Throws with a list of missing
        env vars if any are absent.

    .PARAMETER PassThru
        Return the session object (secrets redacted) instead of nothing.

    .EXAMPLE
        $cred = Get-Credential
        Connect-UKGPro -Hostname 'service5.ultipro.com' `
                       -Credential $cred `
                       -CustomerApiKey 'abc123...' `
                       -UserApiKey    'def456...'

        Explicit flow — original v0.1.0 behavior, still supported.

    .EXAMPLE
        Save-UKGProCredential -Hostname 'service5.ultipro.com' `
                              -CustomerApiKey 'abc...' -UserApiKey 'def...'
        # Then, in every future session:
        Connect-UKGPro -FromVault

        Vault flow — one-time setup with Save-UKGProCredential, then a
        one-line connect that prompts only for the account username/password.

    .EXAMPLE
        $env:UKGPRO_HOSTNAME           = 'service5.ultipro.com'
        $env:UKGPRO_USERNAME           = 'svc_account'
        $env:UKGPRO_PASSWORD           = 'redacted'
        $env:UKGPRO_CUSTOMER_API_KEY   = 'abc...'
        $env:UKGPRO_USER_API_KEY       = 'def...'
        Connect-UKGPro -FromEnvironment

        Environment flow — for CI, scheduled tasks, containers. Password
        supported here because the surrounding secret store (GitHub Actions,
        Azure Pipelines, etc.) injects it into the runtime.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Explicit')]
    [OutputType([void], [pscustomobject])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [string]$Hostname,

        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [Parameter(ParameterSetName = 'FromVault')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [string]$CustomerApiKey,

        [Parameter(Mandatory, ParameterSetName = 'Explicit')]
        [string]$UserApiKey,

        [Parameter(Mandatory, ParameterSetName = 'FromVault')]
        [switch]$FromVault,

        [Parameter(ParameterSetName = 'FromVault')]
        [string]$VaultName,

        [Parameter(Mandatory, ParameterSetName = 'FromEnvironment')]
        [switch]$FromEnvironment,

        [switch]$PassThru
    )

    # --- Resolve the five values based on which parameter set was chosen ---

    if ($PSCmdlet.ParameterSetName -eq 'FromVault') {
        Assert-UKGProSecretManagement -VaultName $VaultName

        $extra = @{}
        if ($VaultName) { $extra['Vault'] = $VaultName }

        $Hostname       = Get-Secret -Name 'UKGPro-Hostname'       -AsPlainText @extra
        $CustomerApiKey = Get-Secret -Name 'UKGPro-CustomerApiKey' -AsPlainText @extra
        $UserApiKey     = Get-Secret -Name 'UKGPro-UserApiKey'     -AsPlainText @extra

        if (-not $Credential) {
            $Credential = Get-Credential -Message 'UKG Pro web service account (username + password)'
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'FromEnvironment') {
        $envMap = @{
            'UKGPRO_HOSTNAME'         = $null
            'UKGPRO_USERNAME'         = $null
            'UKGPRO_PASSWORD'         = $null
            'UKGPRO_CUSTOMER_API_KEY' = $null
            'UKGPRO_USER_API_KEY'     = $null
        }
        foreach ($name in @($envMap.Keys)) {
            $envMap[$name] = [Environment]::GetEnvironmentVariable($name)
        }
        $missing = @($envMap.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Name | Sort-Object)
        if ($missing.Count -gt 0) {
            throw "Connect-UKGPro -FromEnvironment requires these env vars to be set: $($missing -join ', ')"
        }

        $Hostname       = $envMap['UKGPRO_HOSTNAME']
        $CustomerApiKey = $envMap['UKGPRO_CUSTOMER_API_KEY']
        $UserApiKey     = $envMap['UKGPRO_USER_API_KEY']
        $securePassword = ConvertTo-SecureString $envMap['UKGPRO_PASSWORD'] -AsPlainText -Force
        $Credential     = [pscredential]::new($envMap['UKGPRO_USERNAME'], $securePassword)
    }
    # Explicit path: all five values are already parameter-bound.

    # --- Common connect logic (identical across all three flows) ---

    # Normalize the host into a clean https base URL with no trailing slash.
    $h = $Hostname.Trim()
    $h = $h -replace '^https?://', ''
    $h = $h.TrimEnd('/')
    $baseUrl = "https://$h"

    # Pre-compute the Basic token once; store that rather than the raw password.
    # ASCII matches what UKG's own examples use; service-account credentials
    # are ASCII in practice, so this is equivalent to UTF-8 for any real input.
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
        # UserApiKey / CustomerApiKey are secrets — deliberately omitted here.
        [pscustomobject]@{
            BaseUrl     = $script:UKGProSession.BaseUrl
            Username    = $script:UKGProSession.Username
            ConnectedAt = $script:UKGProSession.ConnectedAt
        }
    }
}
