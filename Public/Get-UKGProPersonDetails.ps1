# Whitelist of person-details fields returned in the default (non-PII) response.
# Everything the API returns that is NOT in this list is stripped unless the
# caller passes -IncludePII. See Get-UKGProPersonDetails help for the full
# design rationale.
$script:UKGPro_PersonDetailsSafeFields = @(
    'personId', 'employeeId', 'companyId', 'userName',
    'firstName', 'middleName', 'lastName', 'preferredName',
    'namePrefixCode', 'nameSufixCode',
    'emailAddress',
    'datetimeCreated', 'datetimeChanged',
    'integrationRecordId'
)

function Get-UKGProPersonDetails {
    <#
    .SYNOPSIS
        Retrieves person-level details from UKG Pro (names, contact, address,
        dates, national IDs). Secure-by-default: PII fields are hidden unless
        -IncludePII is passed.

    .DESCRIPTION
        Wraps GET /personnel/v1/person-details. Returns EmpPersonDetails records
        — the person-level view of an employee.

        Privacy defaults: the raw API response contains substantial PII (SSN,
        dateOfBirth, home address, national IDs, protected-class demographics,
        COBRA status, I-9 documents, and more). By default this cmdlet
        projects the response to a whitelisted subset of identity + work-safe
        fields (personId, employeeId, companyId, userName, first/middle/last
        name, preferredName, name prefix/suffix, emailAddress, audit dates,
        integrationRecordId) and strips everything else. Pass -IncludePII to
        opt in to the full response. Without -Force, -IncludePII shows a
        confirmation prompt before returning PII.

        The full API response is always fetched from UKG — the whitelist is
        applied client-side to prevent accidental disclosure through logs,
        exports, or Format-List output.

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

    .PARAMETER IncludePII
        Return the full API response including SSN, dateOfBirth, home address,
        national IDs, and other PII fields. Without this switch, only a
        whitelisted set of identity + work-safe fields is returned.

    .PARAMETER Force
        Skip the confirmation prompt that -IncludePII normally triggers. Use
        in scripts and scheduled tasks where a prompt is not desired.

    .EXAMPLE
        Get-UKGProPersonDetails -EmployeeId '000123'

        Default (safe) response — identity + work-safe fields only. No SSN,
        DOB, home address, etc.

    .EXAMPLE
        Get-UKGProPersonDetails -EmailAddress 'alex.doe@example.com'

        Same secure-by-default projection, looked up by email.

    .EXAMPLE
        Get-UKGProPersonDetails -EmployeeId '000123' -IncludePII

        Interactive: prompts for confirmation, then returns the full record
        including all PII fields.

    .EXAMPLE
        Get-UKGProPersonDetails -EmployeeId '000123' -IncludePII -Force |
            Select-Object employeeId, ssn, dateOfBirth, addressLine1

        Scripted: no prompt, full record returned. -Force acknowledges that
        the caller has a legitimate need and appropriate handling for PII.

    .EXAMPLE
        Get-UKGProPersonDetails -ChangedSince (Get-Date).AddHours(-24)

        Person records changed in the last 24 hours, for an incremental sync
        job. Default (safe) projection.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '',
        Justification = 'Public API name matches the underlying UKG response schema (EmpPersonDetails). Renaming to singular would break every existing caller and diverge from UKG''s own naming.')]
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
        [Parameter()] [int]$PageSize   = 100,

        [Parameter()] [switch]$IncludePII,
        [Parameter()] [switch]$Force
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

    $response = Invoke-UKGProRequest -Method Get -Path '/personnel/v1/person-details' `
        -Query $q -PageSize $PageSize -MaxResults $MaxResults

    if ($IncludePII) {
        if (-not $Force) {
            $query   = 'Include PII fields (SSN, dateOfBirth, home address, national IDs, protected-class demographics, etc.) in the response?'
            $caption = 'Get-UKGProPersonDetails: return full PII'
            if (-not $PSCmdlet.ShouldContinue($query, $caption)) {
                # Caller declined the prompt — return nothing rather than
                # falling back to the redacted view (which would silently
                # succeed and make the -IncludePII call look like it worked).
                return
            }
        }
        return $response
    }

    # Default: strip everything not on the safe list.
    $response | Select-Object -Property $script:UKGPro_PersonDetailsSafeFields
}
