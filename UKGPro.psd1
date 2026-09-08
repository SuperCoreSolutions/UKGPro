@{
    RootModule           = 'UKGPro.psm1'
    ModuleVersion        = '0.3.1'
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
v0.3.1 - Get-UKGProEmploymentDetails -EmailAddress now fans out on
multi-match instead of throwing.

Previously, if person-details returned more than one employee for the
supplied email, the cmdlet threw "Multiple employees (N) found ... use
-EmployeeId to disambiguate" and returned nothing. That was almost
never the useful outcome -- callers who genuinely had duplicate emails
in their tenant just wanted employment records for all of them.

Now: the resolver returns all distinct employeeIds that matched
(deduped by employeeId in case a tenant returns the same person more
than once), and the cmdlet runs employment-details for each and emits
the union. No cmdlet signature changes. Callers who explicitly wanted
the old fail-loud behavior should filter their tenant data before
lookup, or continue to use -EmployeeId.

v0.3.0 (previous) - Termination-date filter redesign (BREAKING).
Get-UKGProEmploymentDetails: -TerminatedOperator removed. Replaced by
four mutually-exclusive intent-named params: -TerminatedOn (equality),
-TerminatedSince (>), -TerminatedBefore (<), and the existing
-TerminatedBetweenStart/-End range.
'@
        }
    }
}
