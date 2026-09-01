function Get-UKGProOrgLevel {
    <#
    .SYNOPSIS
        Retrieves UKG Pro organizational-level configuration rows (numeric
        level + code → description).

    .DESCRIPTION
        Wraps two GET endpoints and routes automatically:
          - List / filtered list: GET /configuration/v1/org-levels
          - Unique lookup by (level, code): GET /configuration/v1/org-levels/{level}/{code}

        When both -Level and -Code are supplied, the unique-lookup endpoint is
        used (needed because the same code can exist at different levels — e.g.
        "ACCT" at level 2 vs level 3 are different rows).

        When -Level is supplied alone (without -Code), the full list is fetched
        and filtered client-side by level, because the list endpoint does not
        accept a level query parameter. This is cheap in practice — org-levels
        tables are typically dozens to a few hundred rows total.

        Requires only the "View" role on the "Company Configuration Integration"
        Web Service.

    .PARAMETER Level
        Organization level number (1-4). Use alone to list all codes at that
        level (client-side filtered), or combine with -Code for a unique lookup.

    .PARAMETER Code
        Organization code (e.g. 'ACCT'). Use alone to list matches across all
        levels (server-side filtered), or combine with -Level for a unique
        lookup.

    .PARAMETER LevelDescription
        Filter list by the level's description (the display name of the level
        itself, e.g. 'Department').

    .PARAMETER BudgetGroup
        Filter list by budget group.

    .PARAMETER ReportingCategory
        Filter list by reporting category code.

    .PARAMETER IsActive
        Filter list by active/inactive status.

    .EXAMPLE
        (Get-UKGProOrgLevel -Level 2 -Code 'ACCT').description

        Unique lookup — the department-code-to-description pattern typical for
        IAM / AD-sync workflows. Returns the single matching row.

    .EXAMPLE
        Get-UKGProOrgLevel -Level 2

        All org-level rows at level 2, regardless of code. Fetched from the
        list endpoint and filtered client-side by level.

    .EXAMPLE
        Get-UKGProOrgLevel -IsActive $true

        All active org-levels across every level. Server-side filter.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter()] [int]$Level,
        [Parameter()] [string]$Code,
        [Parameter()] [string]$LevelDescription,
        [Parameter()] [string]$BudgetGroup,
        [Parameter()] [string]$ReportingCategory,
        [Parameter()] [Nullable[bool]]$IsActive
    )

    $hasLevel = $PSBoundParameters.ContainsKey('Level')
    $hasCode  = $PSBoundParameters.ContainsKey('Code') -and $Code

    # --- Unique lookup: (level, code) tuple goes in the URL path ---
    if ($hasLevel -and $hasCode) {
        return Invoke-UKGProRequest -Method Get `
            -Path "/configuration/v1/org-levels/$Level/$Code" `
            -NoPaging
    }

    # --- Otherwise, hit the list endpoint (with any server-side filters) ---
    $q = @{}
    if ($hasCode)                       { $q['code']              = $Code }
    if ($LevelDescription)              { $q['levelDescription']  = $LevelDescription }
    if ($BudgetGroup)                   { $q['budgetGroup']       = $BudgetGroup }
    if ($ReportingCategory)             { $q['reportingCategory'] = $ReportingCategory }
    if ($PSBoundParameters.ContainsKey('IsActive')) {
        # PowerShell's parameter binder unwraps [Nullable[bool]] to a plain
        # [bool], so $IsActive is the value directly (no .Value accessor).
        # Serialize as lowercase to match REST convention.
        $q['isActive'] = ([string]$IsActive).ToLower()
    }

    $results = Invoke-UKGProRequest -Method Get `
        -Path '/configuration/v1/org-levels' `
        -Query $q `
        -NoPaging

    # -Level alone (no -Code) => client-side filter by level, since the list
    # endpoint has no level query parameter.
    if ($hasLevel -and -not $hasCode) {
        return $results | Where-Object { $_.level -eq $Level }
    }
    return $results
}
