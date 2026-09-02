function Save-UKGProCredential {
    <#
    .SYNOPSIS
        Saves the tenant-level UKG Pro connection values (hostname + two API
        keys) to a Microsoft.PowerShell.SecretManagement vault so subsequent
        calls to `Connect-UKGPro -FromVault` don't need to hand-pass them.

    .DESCRIPTION
        Writes three secrets: UKGPro-Hostname, UKGPro-CustomerApiKey,
        UKGPro-UserApiKey. Existing secrets under those names are overwritten.

        Deliberately does NOT store the web-service-account username or
        password. Those are prompted at connect time (or supplied via
        -Credential to Connect-UKGPro). This is a defense-in-depth choice:
        a compromised local vault reveals only tenant-level API config,
        never the account password.

        Requires the Microsoft.PowerShell.SecretManagement module (plus a
        registered vault such as SecretStore). If missing, throws with a
        copy-pasteable install command.

    .PARAMETER Hostname
        Tenant service endpoint host (e.g. 'service5.ultipro.com'). Same
        value you would pass to Connect-UKGPro -Hostname.

    .PARAMETER CustomerApiKey
        Tenant Customer API Key. Stored as SecureString.

    .PARAMETER UserApiKey
        User API Key from the web service account. Stored as SecureString.

    .PARAMETER VaultName
        Name of a specific SecretManagement vault to write to. When omitted,
        uses the current default vault (Get-SecretVault | Where-Object IsDefault).

    .EXAMPLE
        Save-UKGProCredential -Hostname 'service5.ultipro.com' `
                              -CustomerApiKey 'abc123...' `
                              -UserApiKey    'def456...'

        One-time setup on a workstation. From now on:
        Connect-UKGPro -FromVault   # prompts for username/password only

    .EXAMPLE
        Save-UKGProCredential -Hostname 'service5.ultipro.com' `
                              -CustomerApiKey 'abc123...' `
                              -UserApiKey    'def456...' `
                              -VaultName 'UKGPro-Prod'

        Save to a specific vault (useful if multiple tenants co-exist).
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Hostname,

        [Parameter(Mandatory)]
        [string]$CustomerApiKey,

        [Parameter(Mandatory)]
        [string]$UserApiKey,

        [Parameter()]
        [string]$VaultName
    )

    Assert-UKGProSecretManagement -VaultName $VaultName

    $extra = @{}
    if ($VaultName) { $extra['Vault'] = $VaultName }

    Set-Secret -Name 'UKGPro-Hostname'       -Secret $Hostname                                                @extra
    Set-Secret -Name 'UKGPro-CustomerApiKey' -Secret (ConvertTo-SecureString $CustomerApiKey -AsPlainText -Force) @extra
    Set-Secret -Name 'UKGPro-UserApiKey'     -Secret (ConvertTo-SecureString $UserApiKey     -AsPlainText -Force) @extra

    Write-Verbose "UKG Pro tenant secrets saved (hostname + two API keys). Username/password NOT stored — supply at Connect-UKGPro time."
}
