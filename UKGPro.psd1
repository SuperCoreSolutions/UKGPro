@{
    RootModule           = 'UKGPro.psm1'
    ModuleVersion        = '0.1.0'
    CompatiblePSEditions  = @('Desktop', 'Core')
    GUID                 = 'ce04853e-e752-4d4b-b9a5-3297f933dfd2'

    Author               = 'Don Sheehan'
    CompanyName          = 'Super Core Solutions LLC'
    Copyright            = '(c) Super Core Solutions LLC. All rights reserved.'

    Description          = 'PowerShell wrapper for the UKG Pro HCM REST API (Pro Employee Data / personnel v1). Retrieve employment details and related employee data for HR, offboarding, and IAM automation.'

    PowerShellVersion    = '5.1'

    FunctionsToExport    = @(
        'Connect-UKGPro'
        'Disconnect-UKGPro'
        'Get-UKGProEmploymentDetails'
        'Get-UKGProPersonDetails'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('UKG', 'UKGPro', 'HCM', 'Personnel', 'Employee', 'REST', 'IAM', 'Offboarding')
            LicenseUri   = 'https://github.com/SuperCoreSolutions/UKGPro/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/SuperCoreSolutions/UKGPro'
            ReleaseNotes = 'Initial scaffold: Basic + API-key auth (Connect/Disconnect) and Get-UKGProEmploymentDetails with page/per_Page pagination and friendly date filters.'
        }
    }
}
