function Add-UKGProTypeName {
    <#
    .SYNOPSIS
        Prepends a module-scoped TypeName to each input object so PowerShell's
        default formatter picks up the matching View in UKGPro.format.ps1xml.

    .DESCRIPTION
        Each Get- cmdlet routes its Invoke-UKGProRequest results through this
        helper (e.g. `... | Add-UKGProTypeName -TypeName 'UKGPro.EmploymentDetails'`).
        The TypeName is inserted at position 0 so PowerShell matches the
        module's TableControl before any generic PSCustomObject view.

        Objects still carry every original property; only the default
        rendering changes. `| Format-List` on tagged objects falls back to
        PowerShell's built-in "show every property" behavior because the
        format file deliberately defines no ListControl for the type.

        Null inputs are dropped rather than propagated so the pipeline stays
        clean when an underlying call returned nothing.

    .NOTES
        Internal helper. Not exported.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [pscustomobject]$InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TypeName
    )

    process {
        if ($null -eq $InputObject) { return }
        $InputObject.PSObject.TypeNames.Insert(0, $TypeName)
        $InputObject
    }
}
