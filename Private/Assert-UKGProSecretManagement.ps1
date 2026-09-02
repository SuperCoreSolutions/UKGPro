function Assert-UKGProSecretManagement {
    <#
    .SYNOPSIS
        Verifies Microsoft.PowerShell.SecretManagement is installed; throws
        with a copy-pasteable install command if not.

    .NOTES
        Internal helper for Save-UKGProCredential, Update-UKGProCredential,
        and Connect-UKGPro -FromVault. SecretManagement is a soft dependency:
        the explicit-args Connect-UKGPro flow works without it.
    #>
    [CmdletBinding()]
    param ()

    if (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement) {
        return
    }

    throw @"
This flow requires Microsoft.PowerShell.SecretManagement. Install with:

  Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
  Install-Module Microsoft.PowerShell.SecretStore        -Scope CurrentUser

The SecretStore module provides the default local vault. If you prefer
another SecretManagement backend (Azure KeyVault, KeePass, etc.), install
that vault module instead and register it with Register-SecretVault.
"@
}
