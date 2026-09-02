@{
    RootModule           = 'UKGPro.psm1'
    ModuleVersion        = '0.3.0'
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
v0.3.0 - Termination-date filter redesign (BREAKING).

Get-UKGProEmploymentDetails: -TerminatedOperator is REMOVED. The
single -TerminatedOn <date> parameter is replaced with three
intent-named parameters, each with its own natural semantic and no
operator argument required:

  -TerminatedOn <date>      terminated on that exact date (equality)
  -TerminatedSince <date>   terminated on/after that date (>)
  -TerminatedBefore <date>  terminated on/before that date (<)
  -TerminatedBetweenStart / -TerminatedBetweenEnd    range (unchanged)

Migration:
  OLD: -TerminatedOn X -TerminatedOperator GreaterThan  -> -TerminatedSince X
  OLD: -TerminatedOn X -TerminatedOperator LessThan     -> -TerminatedBefore X
  OLD: -TerminatedOn X -TerminatedOperator EqualTo      -> -TerminatedOn X (default now)
  OLD: -TerminatedOn X (no -TerminatedOperator)         -> -TerminatedSince X
    (old default was GreaterThan; the parameter name promised equality
     but the behavior returned "after that date" -- root cause of the fix)

The four termination-filter parameters are mutually exclusive via
parameter sets, so PowerShell now catches "wait, which one did I
mean?" mistakes at bind time.

v0.2.1 (previous) - Friendlier first-run errors for SecretManagement
setup: Save/Update-UKGProCredential and Connect-UKGPro -FromVault now
detect missing module / missing vault / missing default vault up
front and throw copy-pasteable setup commands.
'@
        }
    }
}
