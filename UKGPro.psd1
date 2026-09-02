@{
    RootModule           = 'UKGPro.psm1'
    ModuleVersion        = '0.2.1'
    CompatiblePSEditions  = @('Desktop', 'Core')
    GUID                 = 'ce04853e-e752-4d4b-b9a5-3297f933dfd2'

    Author               = 'Don Sheehan'
    CompanyName          = 'Super Core Solutions LLC'
    Copyright            = '(c) Super Core Solutions LLC. All rights reserved.'

    Description          = 'General-purpose PowerShell wrapper for the UKG Pro HCM REST API. Provides Get- cmdlets for personnel/v1 (employment, person) and configuration/v1 (org-levels, jobs, job-groups, company-details) endpoints with unified authentication, pagination, date-filter handling, secure-by-default PII redaction, and optional SecretManagement-backed auth.'

    PowerShellVersion    = '5.1'

    FunctionsToExport    = @(
        'Connect-UKGPro'
        'Disconnect-UKGPro'
        'Save-UKGProCredential'
        'Update-UKGProCredential'
        'Get-UKGProEmploymentDetails'
        'Get-UKGProPersonDetails'
        'Get-UKGProOrgLevel'
        'Get-UKGProJobGroup'
        'Get-UKGProJob'
        'Get-UKGProCompanyDetails'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('UKG', 'UKGPro', 'HCM', 'Personnel', 'Employee', 'REST', 'IAM', 'HR', 'SecretManagement')
            LicenseUri   = 'https://github.com/SuperCoreSolutions/UKGPro/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/SuperCoreSolutions/UKGPro'
            ExternalModuleDependencies = @('Microsoft.PowerShell.SecretManagement')
            ReleaseNotes = @'
v0.2.1 - Better first-run errors for SecretManagement setup.

Save-UKGProCredential / Update-UKGProCredential / Connect-UKGPro
-FromVault now detect three fresh-machine failure modes up front and
throw copy-pasteable setup commands instead of surfacing the raw
"no vault provided and there is no default vault designated" error
from Set-Secret:
  1. Microsoft.PowerShell.SecretManagement not installed.
  2. Module installed but no vault registered (Install-Module
     SecretStore + Register-SecretVault -DefaultVault).
  3. Vaults registered but none marked default (Set-SecretVaultDefault
     or supply -VaultName).

No cmdlet signatures changed. No breaking changes.

v0.2.0 (previous) - Expanded read surface + auth ergonomics + secure
PII defaults. Cmdlets: Connect-UKGPro (Explicit / -FromVault /
-FromEnvironment), Disconnect-UKGPro, Save-UKGProCredential,
Update-UKGProCredential (hostname + tenant API keys only --
username/password are never persisted in the vault by design),
Get-UKGProEmploymentDetails, Get-UKGProPersonDetails
(secure-by-default PII redaction, opt in with -IncludePII),
Get-UKGProOrgLevel, Get-UKGProJobGroup, Get-UKGProJob (v2 endpoints),
Get-UKGProCompanyDetails. Unified auth (Basic + US-Customer-API-Key +
x-api-key), automatic page/per_Page pagination, friendly date filters
for UKG's operator-prefixed date syntax. Every Get- cmdlet works with
a View-only UKG service account.
'@
        }
    }
}
