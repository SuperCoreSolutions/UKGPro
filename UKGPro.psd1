@{
    RootModule           = 'UKGPro.psm1'
    ModuleVersion        = '1.0.0'
    FormatsToProcess     = @('UKGPro.format.ps1xml')
    CompatiblePSEditions  = @('Desktop', 'Core')
    GUID                 = 'ce04853e-e752-4d4b-b9a5-3297f933dfd2'

    Author               = 'Don Sheehan'
    CompanyName          = 'Super Core Solutions LLC'
    Copyright            = '(c) Super Core Solutions LLC. All rights reserved.'

    Description          = 'PowerShell module for the UKG Pro HCM REST API, focused on read-only IAM/offboarding automation. Provides Get- cmdlets for employment, person, org-level, job, job-group, company-details, and location lookups with unified authentication, pagination, date-filter handling, secure-by-default PII redaction, and optional SecretManagement-backed auth.'

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
        'Get-UKGProLocation'
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
v1.0.0 - First stable release. The public API surface (11 exported
cmdlets, parameter shapes, output types, compact-view formatting) is
committed: any future breaking change bumps to 2.0. Also in this
release: new Get-UKGProLocation cmdlet wrapping
/configuration/v1/locations (list + unique lookup by -Code, with
-CountryCode / -IsActive filters; compact view: LocationCode,
Description, City, IsActive). Manifest description also tightened to
accurately reflect scope (read-only IAM/offboarding-focused Get-
surface) rather than "general-purpose UKG Pro HCM wrapper".

v0.3.3 (previous) - Compact default table views extended to the remaining
Get- cmdlets (Get-UKGProPersonDetails, Get-UKGProOrgLevel,
Get-UKGProJobGroup, Get-UKGProJob, Get-UKGProCompanyDetails), so
every Get- cmdlet in the module now shares the same Get-Mailbox-style
output convention introduced for Get-UKGProEmploymentDetails in
v0.3.2. Column choices:

  PersonDetails    : EmployeeId, FirstName, LastName, EmailAddress
  OrgLevel         : Level, Code, Description, IsActive
  JobGroup         : JobGroupCode, Description, CountryCode
  Job              : JobCode, Title, CountryCode, IsActive
  CompanyDetails   : CompanyId, CompanyCode, MasterCompanyId, IsMaster

Also factored the tagging into a shared private Add-UKGProTypeName
helper (Get-UKGProEmploymentDetails swapped from its inline
ForEach-Object to use it, for consistency). No cmdlet signature or
property changes.

v0.3.2 (previous) - Compact default table view for
Get-UKGProEmploymentDetails (EmployeeId, CompanyId, JobTitle, Status).
Every property still on the object; `| Format-List` shows them all,
matching the Get-Mailbox convention in Exchange PowerShell.
Introduced UKGPro.format.ps1xml + FormatsToProcess in the manifest.

v0.3.1 (previous) - Get-UKGProEmploymentDetails -EmailAddress now
fans out on multi-match instead of throwing. If person-details returns
multiple distinct employees for the supplied email, records for all
of them are returned rather than a "use -EmployeeId to disambiguate"
error.

v0.3.0 (previous) - Termination-date filter redesign (BREAKING).
Get-UKGProEmploymentDetails: -TerminatedOperator removed. Replaced by
four mutually-exclusive intent-named params: -TerminatedOn (equality),
-TerminatedSince (>), -TerminatedBefore (<), and the existing
-TerminatedBetweenStart/-End range.
'@
        }
    }
}
