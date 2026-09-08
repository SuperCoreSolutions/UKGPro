function Resolve-UKGProEmployeeIdByEmail {
    <#
    .SYNOPSIS
        Resolves an email address to one or more UKG Pro employee ID +
        company ID pairs.

    .DESCRIPTION
        Internal helper. Hits GET /personnel/v1/person-details?emailAddress=<value>
        to translate a work-email into the employee's numeric identifiers so
        other Get- cmdlets can filter by a human-friendly key.

        Always returns an ARRAY of records — one per distinct employeeId
        that matched. Callers must handle the multi-match case (e.g. by
        fanning out subsequent queries per resolved id). Throws only when
        no matches were found.

        Duplicate person records sharing an employeeId (rare but possible
        in some tenants) are deduped so callers don't waste a round trip
        per duplicate.

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
    [OutputType([pscustomobject[]])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$EmailAddress
    )

    # PageSize 10 leaves a bit of headroom for the rare tenant that shares
    # an email across accounts. Anything larger than this and the caller
    # should re-think using email as an identifier.
    # NOTE: variable is $people, not $matches ($matches is a PS automatic var).
    $people = @(Invoke-UKGProRequest -Method Get `
        -Path '/personnel/v1/person-details' `
        -Query @{ emailAddress = $EmailAddress } `
        -PageSize 10)

    if ($people.Count -eq 0) {
        throw "No employee found in UKG Pro with email address '$EmailAddress'."
    }

    # Dedupe by employeeId: if a tenant returns the same person twice
    # (extra sanity), only fan out once.
    $seen = @{}
    foreach ($person in $people) {
        $eid = $person.employeeId
        if ($null -eq $eid -or $seen.ContainsKey($eid)) { continue }
        $seen[$eid] = $true
        [pscustomobject]@{
            EmployeeId = $eid
            CompanyId  = $person.companyId
        }
    }
}
