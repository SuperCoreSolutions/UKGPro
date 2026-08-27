#Requires -Version 5.1

<#
    UKGPro root module.
    Dot-sources every .ps1 under Private/ and Public/, then exports only the
    Public functions. One function per file keeps the module easy to navigate
    on GitHub and lets Pester target functions individually.
#>

$Private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)
$Public  = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public')  -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($file in @($Private + $Public)) {
    try {
        . $file.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($file.FullName): $_"
    }
}

Export-ModuleMember -Function $Public.BaseName
