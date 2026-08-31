function Resolve-UKGProEmployeeIdByEmail {
    <#
    .SYNOPSIS
        Resolves an email address to a UKG Pro employee ID + company ID.

    .DESCRIPTION
        Internal helper. Hits GET /personnel/v1/person-details?emailAddress=<value>
        to translate a work-email into the employee's numeric identifiers so
        other Get- cmdlets can filter by a human-friendly key.

        Uses a plain GET (no POST/employee-ids) so the caller's UKG service
        account only needs the View role on the Employee Person Details Web
        Service.

        The response schema (EmpPersonDetails) carries heavy PII (SSN, DOB,
        national ID, addresses). Only employeeId + companyId are returned to
        the caller; nothing else is logged or persisted.

    .NOTES
        Internal helper. Not exported.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$EmailAddress
    )

    # PageSize 5 is deliberately small: any real tenant should return 0 or 1.
    # If a tenant returns more (e.g. duplicate accounts), we want to see them
    # to fail loudly rather than silently pick the first.
    # NOTE: variable is $people, not $matches ($matches is a PS automatic var).
    $people = Invoke-UKGProRequest -Method Get `
        -Path '/personnel/v1/person-details' `
        -Query @{ emailAddress = $EmailAddress } `
        -PageSize 5

    $count = @($people).Count

    if ($count -eq 0) {
        throw "No employee found in UKG Pro with email address '$EmailAddress'."
    }
    if ($count -gt 1) {
        throw "Multiple employees ($count) found in UKG Pro for email '$EmailAddress'. Use -EmployeeId to disambiguate."
    }

    $person = @($people)[0]
    [pscustomobject]@{
        EmployeeId = $person.employeeId
        CompanyId  = $person.companyId
    }
}
