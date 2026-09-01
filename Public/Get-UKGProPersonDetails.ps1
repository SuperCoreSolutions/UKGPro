function Get-UKGProPersonDetails {
    <#
    .SYNOPSIS
        Retrieves person-level details from UKG Pro (names, contact, address,
        dates, national IDs).

    .DESCRIPTION
        Wraps GET /personnel/v1/person-details. Returns EmpPersonDetails records
        — the person-level view of an employee including firstName/lastName,
        emailAddress, home address, dateOfBirth, nationalId, and other
        demographic fields.

        Unlike Get-UKGProEmploymentDetails, this endpoint accepts emailAddress
        as a native query parameter, so both -EmployeeId and -EmailAddress
        translate directly into server-side filters — no resolver hop needed.

        All filters are optional and applied server-side. Results are paginated
        automatically (page/per_Page) unless -MaxResults caps them. Requires
        only the "View" role on the "Employee Person Details" Web Service.

    .PARAMETER EmployeeId
        Filter by employee identifier. Mutually exclusive with -EmailAddress.

    .PARAMETER EmailAddress
        Filter by the employee's UKG-registered email address. Passed directly
        to the person-details endpoint as the `emailAddress` query parameter.
        Mutually exclusive with -EmployeeId.

    .PARAMETER CompanyId
        Filter by company identifier. Useful to narrow lookups in multi-company
        tenants.

    .PARAMETER LastName
        Filter by last name. The underlying API accepts a `*` wildcard in this
        field, so 'Smi*' will match 'Smith', 'Smiley', etc.

    .PARAMETER ChangedSince
        Return records whose `dateTimeChanged` is greater than this date/time
        (useful for incremental syncs).

    .PARAMETER MaxResults
        Cap total records across all pages. 0 = all.

    .PARAMETER PageSize
        Rows per page to request (default 100).

    .EXAMPLE
        Get-UKGProPersonDetails -EmployeeId '000123'

        Retrieves the person record for one employee by ID.

    .EXAMPLE
        Get-UKGProPersonDetails -EmailAddress 'alex.doe@example.com'

        Retrieves the person record by work email. Native single-request
        lookup — no resolver call.

    .EXAMPLE
        Get-UKGProPersonDetails -ChangedSince (Get-Date).AddHours(-24)

        Person records changed in the last 24 hours, for an incremental sync
        job.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter()] [string]$EmployeeId,
        [Parameter()] [string]$EmailAddress,
        [Parameter()] [string]$CompanyId,
        [Parameter()] [string]$LastName,

        [Parameter()]
        [datetime]$ChangedSince,

        [Parameter()] [int]$MaxResults = 0,
        [Parameter()] [int]$PageSize   = 100
    )

    if ($EmailAddress -and $EmployeeId) {
        throw "-EmailAddress and -EmployeeId cannot be used together. Choose one."
    }

    $q = @{}
    if ($EmployeeId)   { $q['employeeId']   = $EmployeeId }
    if ($EmailAddress) { $q['emailAddress'] = $EmailAddress }
    if ($CompanyId)    { $q['companyId']    = $CompanyId }
    if ($LastName)     { $q['lastName']     = $LastName }

    if ($PSBoundParameters.ContainsKey('ChangedSince')) {
        $q['dateTimeChanged'] = ConvertTo-UKGProDateFilter -Operator GreaterThan -Date $ChangedSince
    }

    Invoke-UKGProRequest -Method Get -Path '/personnel/v1/person-details' `
        -Query $q -PageSize $PageSize -MaxResults $MaxResults
}
