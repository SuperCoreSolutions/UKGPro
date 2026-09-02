function Assert-UKGProSecretManagement {
    <#
    .SYNOPSIS
        Verifies Microsoft.PowerShell.SecretManagement is installed AND that a
        usable vault is registered. Throws with copy-pasteable setup commands
        for whichever piece is missing.

    .PARAMETER VaultName
        Optional. If supplied, verifies a vault with this name is registered.
        If omitted, verifies at least one vault is registered AND that one of
        them is marked as the default vault.

    .NOTES
        Internal helper for Save-UKGProCredential, Update-UKGProCredential,
        and Connect-UKGPro -FromVault. SecretManagement is a soft dependency
        of the module: the explicit-args Connect-UKGPro flow works without it.

        Three failure modes we can catch here — the raw Set-Secret error is
        cryptic enough that users on a fresh machine ("no vault provided and
        there is no default vault designated") aren't sure what's missing:
          1. SecretManagement module not installed at all.
          2. Module installed but no vault registered.
          3. Vaults registered but none marked default AND caller didn't
             supply -VaultName.
    #>
    [CmdletBinding()]
    param (
        [string]$VaultName
    )

    if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement)) {
        throw @"
This flow requires Microsoft.PowerShell.SecretManagement AND a vault
provider (SecretStore is Microsoft's default cross-platform choice).
One-time setup:

  Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
  Install-Module Microsoft.PowerShell.SecretStore        -Scope CurrentUser
  Register-SecretVault -Name SecretStore ``
                       -ModuleName Microsoft.PowerShell.SecretStore ``
                       -DefaultVault

The first Set-Secret call will prompt for a vault password (used to
unlock the store on subsequent sessions). Run
Set-SecretStoreConfiguration afterward to tune password / timeout.

If you prefer another SecretManagement backend (Azure KeyVault, KeePass,
1Password, etc.), install that vault module instead and register it in
the last step above.
"@
    }

    Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop

    $vaults = @(Get-SecretVault -ErrorAction SilentlyContinue)

    if ($vaults.Count -eq 0) {
        throw @"
Microsoft.PowerShell.SecretManagement is installed, but no vault is
registered on this machine. Install a vault provider and register it —
SecretStore is Microsoft's default cross-platform choice:

  Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser
  Register-SecretVault -Name SecretStore ``
                       -ModuleName Microsoft.PowerShell.SecretStore ``
                       -DefaultVault

The first Set-Secret call will prompt you to create a vault password
(used to unlock the store on subsequent sessions). Run
Set-SecretStoreConfiguration afterward to tune password / timeout.
"@
    }

    if ($VaultName) {
        if (-not ($vaults | Where-Object Name -eq $VaultName)) {
            $registered = ($vaults | ForEach-Object Name) -join ', '
            throw @"
No SecretManagement vault named '$VaultName' is registered. Registered
vault(s): $registered.

Register '$VaultName' with the appropriate vault module, e.g.:

  Register-SecretVault -Name $VaultName ``
                       -ModuleName Microsoft.PowerShell.SecretStore

Or omit -VaultName to use whichever vault is marked default.
"@
        }
        return
    }

    if (-not ($vaults | Where-Object IsDefault)) {
        $registered = ($vaults | ForEach-Object Name) -join ', '
        throw @"
Vault(s) registered ($registered) but none is marked as the default.
Either:

  1. Mark one as default:
       Set-SecretVaultDefault -Name <VaultName>
  2. Or re-run this cmdlet with an explicit -VaultName.
"@
    }
}
