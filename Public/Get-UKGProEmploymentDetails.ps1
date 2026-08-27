function Get-UKGProEmploymentDetails {
    <#
    .SYNOPSIS
        Retrieves employment record details from UKG Pro.

    .DESCRIPTION
        Wraps GET /personnel/v1/employment-details. Returns employment records
        including status, job, work location, supervisor, and key dates
        (hire, termination, retirement) — the fields most useful for offboarding
        and IAM workflows.

        All filters are optional and applied server-side. Results are paginated
        automatically (page/per_Page) unless -MaxResults caps them.

        Date filters use friendly parameters: pass a [datetime] and choose the
        comparison via the matching *-Operator parameter (default GreaterThan).
        The module formats UKG's operator-prefixed MM-DD-YYYY syntax for you.

    .PARAMETER CompanyId
        Filter by company identifier.

    .PARAMETER EmployeeId
        Filter by employee identifier.

    .PARAMETER EmployeeNumber
        Filter by employee number.

    .PARAMETER EmployeeStatusCode
        Filter by employee status code (e.g. active/terminated codes as defined
        in your tenant).

    .PARAMETER EmployeeTypeCode
        Filter by employee type code.

    .PARAMETER SupervisorId
        Filter by supervisor ID.

    .PARAMETER JobTitle
        Filter by job title.

    .PARAMETER PrimaryJobCode
        Filter by primary job code.

    .PARAMETER PrimaryWorkLocationCode
        Filter by primary work location code.

    .PARAMETER TerminatedOn
        Filter on date of termination. Combine with -TerminatedOperator.

    .PARAMETER TerminatedOperator
        Comparison for -TerminatedOn: LessThan, GreaterThan (default), EqualTo.

    .PARAMETER TerminatedBetweenStart / -TerminatedBetweenEnd
        Filter for terminations within an inclusive date range.

    .PARAMETER ChangedSince
        Return records whose dateTimeChanged is greater than this date/time
        (useful for incremental syncs).

    .PARAMETER MaxResults
        Cap total records across all pages. 0 = all.

    .PARAMETER PageSize
        Rows per page to request (default 100).

    .EXAMPLE
        Get-UKGProEmploymentDetails -EmployeeId '000123'

        Retrieves employment details for one employee.

    .EXAMPLE
        Get-UKGProEmploymentDetails -TerminatedOn (Get-Date).AddDays(-30) -TerminatedOperator GreaterThan

        Employees terminated in the last 30 days (offboarding candidates).

    .EXAMPLE
        Get-UKGProEmploymentDetails -TerminatedBetweenStart '2026-01-01' -TerminatedBetweenEnd '2026-03-31'

        Employees terminated in Q1 2026.

    .EXAMPLE
        Get-UKGProEmploymentDetails -ChangedSince (Get-Date).AddHours(-24)

        Records changed in the last day, for an incremental sync.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Standard')]
    [OutputType([pscustomobject])]
    param (
        [Parameter()] [string]$CompanyId,
        [Parameter()] [string]$EmployeeId,
        [Parameter()] [string]$EmployeeNumber,
        [Parameter()] [string]$EmployeeStatusCode,
        [Parameter()] [string]$EmployeeTypeCode,
        [Parameter()] [string]$SupervisorId,
        [Parameter()] [string]$JobTitle,
        [Parameter()] [string]$PrimaryJobCode,
        [Parameter()] [string]$PrimaryWorkLocationCode,

        # --- Termination date, single-comparison form ---
        [Parameter(ParameterSetName = 'Standard')]
        [datetime]$TerminatedOn,

        [Parameter(ParameterSetName = 'Standard')]
        [ValidateSet('LessThan', 'GreaterThan', 'EqualTo')]
        [string]$TerminatedOperator = 'GreaterThan',

        # --- Termination date, range form ---
        [Parameter(Mandatory, ParameterSetName = 'TerminatedRange')]
        [datetime]$TerminatedBetweenStart,

        [Parameter(Mandatory, ParameterSetName = 'TerminatedRange')]
        [datetime]$TerminatedBetweenEnd,

        # --- Incremental sync helper ---
        [Parameter()]
        [datetime]$ChangedSince,

        [Parameter()] [int]$MaxResults = 0,
        [Parameter()] [int]$PageSize   = 100
    )

    $q = @{}
    if ($CompanyId)               { $q['companyId']               = $CompanyId }
    if ($EmployeeId)              { $q['employeeId']              = $EmployeeId }
    if ($EmployeeNumber)          { $q['employeeNumber']          = $EmployeeNumber }
    if ($EmployeeStatusCode)      { $q['employeeStatusCode']      = $EmployeeStatusCode }
    if ($EmployeeTypeCode)        { $q['employeeTypeCode']        = $EmployeeTypeCode }
    if ($SupervisorId)            { $q['supervisorID']            = $SupervisorId }
    if ($JobTitle)                { $q['jobTitle']                = $JobTitle }
    if ($PrimaryJobCode)          { $q['primaryJobCode']          = $PrimaryJobCode }
    if ($PrimaryWorkLocationCode) { $q['primaryWorkLocationCode'] = $PrimaryWorkLocationCode }

    # Termination date filter (operator-prefixed value).
    if ($PSCmdlet.ParameterSetName -eq 'TerminatedRange') {
        $q['dateOfTermination'] = ConvertTo-UKGProDateFilter -Operator Between `
            -RangeStart $TerminatedBetweenStart -RangeEnd $TerminatedBetweenEnd
    }
    elseif ($PSBoundParameters.ContainsKey('TerminatedOn')) {
        $q['dateOfTermination'] = ConvertTo-UKGProDateFilter -Operator $TerminatedOperator -Date $TerminatedOn
    }

    # Incremental sync: dateTimeChanged greater-than.
    if ($PSBoundParameters.ContainsKey('ChangedSince')) {
        $q['dateTimeChanged'] = ConvertTo-UKGProDateFilter -Operator GreaterThan -Date $ChangedSince
    }

    Invoke-UKGProRequest -Method Get -Path '/personnel/v1/employment-details' `
        -Query $q -PageSize $PageSize -MaxResults $MaxResults
}
