@{
    RootModule           = 'UKGPro.psm1'
    ModuleVersion        = '0.3.2'
    FormatsToProcess     = @('UKGPro.format.ps1xml')
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
v0.3.2 - Compact default table views for every Get- cmdlet.

Records returned by the Get-UKGProEmploymentDetails,
Get-UKGProPersonDetails, Get-UKGProOrgLevel, Get-UKGProJobGroup,
Get-UKGProJob, and Get-UKGProCompanyDetails cmdlets now render as
short 3-4 column tables by default -- much easier to scan when a
query returns multiple records (e.g. the -EmailAddress fan-out from
v0.3.1 or any list query). Every property is still on the object;
`| Format-List` shows them all, same convention Get-Mailbox uses in
Exchange PowerShell.

Column choices (see UKGPro.format.ps1xml):
  EmploymentDetails: EmployeeId, CompanyId, JobTitle, Status
  PersonDetails    : EmployeeId, FirstName, LastName, EmailAddress
  OrgLevel         : Level, Code, Description, IsActive
  JobGroup         : JobGroupCode, Description, CountryCode
  Job              : JobCode, Title, CountryCode, IsActive
  CompanyDetails   : CompanyId, CompanyCode, MasterCompanyId, IsMaster

Implementation: new UKGPro.format.ps1xml + records tagged with a
module-scoped TypeName (UKGPro.EmploymentDetails, UKGPro.PersonDetails,
etc.) via a shared private helper Add-UKGProTypeName. No cmdlet
signature changes; no property changes; existing scripts that access
properties by name are unaffected. Scripts that captured Out-String
output would see different formatted text.

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
