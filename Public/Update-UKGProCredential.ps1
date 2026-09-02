function Update-UKGProCredential {
    <#
    .SYNOPSIS
        Partially updates the stored UKG Pro tenant secrets — rotate one API
        key or change the hostname without re-entering everything.

    .DESCRIPTION
        Writes only the secrets whose parameters were supplied. Existing
        secrets for unlisted names are left untouched.

        At least one of -Hostname, -CustomerApiKey, -UserApiKey must be
        supplied — otherwise the call is a no-op and the cmdlet throws to
        make the intent clear.

        Like Save-UKGProCredential, this cmdlet never touches the
        web-service-account username or password.

    .PARAMETER Hostname
        New tenant service endpoint host.

    .PARAMETER CustomerApiKey
        New Customer API Key. Stored as SecureString.

    .PARAMETER UserApiKey
        New User API Key. Stored as SecureString.

    .PARAMETER VaultName
        Name of a specific SecretManagement vault to write to. Should match
        whatever vault Save-UKGProCredential was originally called with.

    .EXAMPLE
        Update-UKGProCredential -CustomerApiKey '<new-key>'

        Rotate a leaked Customer API Key. Hostname and UserApiKey remain
        as previously saved.

    .EXAMPLE
        Update-UKGProCredential -Hostname 'service9.ultipro.com'

        Point the stored config at a different tenant endpoint (e.g. after
        UKG-driven service migration).
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter()]
        [string]$Hostname,

        [Parameter()]
        [string]$CustomerApiKey,

        [Parameter()]
        [string]$UserApiKey,

        [Parameter()]
        [string]$VaultName
    )

    if (-not ($PSBoundParameters.ContainsKey('Hostname') -or
              $PSBoundParameters.ContainsKey('CustomerApiKey') -or
              $PSBoundParameters.ContainsKey('UserApiKey'))) {
        throw "Update-UKGProCredential requires at least one of -Hostname, -CustomerApiKey, or -UserApiKey."
    }

    Assert-UKGProSecretManagement

    $extra = @{}
    if ($VaultName) { $extra['Vault'] = $VaultName }

    $updated = @()
    if ($PSBoundParameters.ContainsKey('Hostname')) {
        if ($PSCmdlet.ShouldProcess('UKGPro-Hostname', 'Set-Secret')) {
            Set-Secret -Name 'UKGPro-Hostname' -Secret $Hostname @extra
            $updated += 'Hostname'
        }
    }
    if ($PSBoundParameters.ContainsKey('CustomerApiKey')) {
        if ($PSCmdlet.ShouldProcess('UKGPro-CustomerApiKey', 'Set-Secret')) {
            Set-Secret -Name 'UKGPro-CustomerApiKey' `
                -Secret (ConvertTo-SecureString $CustomerApiKey -AsPlainText -Force) @extra
            $updated += 'CustomerApiKey'
        }
    }
    if ($PSBoundParameters.ContainsKey('UserApiKey')) {
        if ($PSCmdlet.ShouldProcess('UKGPro-UserApiKey', 'Set-Secret')) {
            Set-Secret -Name 'UKGPro-UserApiKey' `
                -Secret (ConvertTo-SecureString $UserApiKey -AsPlainText -Force) @extra
            $updated += 'UserApiKey'
        }
    }

    Write-Verbose ("UKG Pro secrets updated: {0}." -f ($updated -join ', '))
}
