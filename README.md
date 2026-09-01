# UKGPro

A general-purpose PowerShell module wrapping the **UKG Pro HCM** REST API. Provides typed `Get-` cmdlets for the `personnel/v1` (employment records, person details) and `configuration/v1` (org-levels, more to come) endpoint families, with a shared authentication, pagination, and date-filter layer so callers work with objects and parameters instead of URL strings and query encoding.

Common use cases include HR data extracts, employee-record reporting, IAM provisioning/deprovisioning workflows, and one-off lookups from an interactive PowerShell session — but nothing in the module is tied to any single workflow. Any script that needs to read UKG Pro data can use it.

Companion to the separate [UKGHRSD](../UKGHRSD) module (which covers UKG HR Service Delivery). The two are intentionally separate: different platform, authentication, and base URL.

> Status: early module (v0.1.0). Ships with authentication, session management, and `Get-` cmdlets for employment details, person details, and org-level configuration. More cmdlets in active development.

## Install

```powershell
# From PowerShell Gallery (once published)
Install-Module UKGPro

# Or from source
git clone https://github.com/SuperCoreSolutions/UKGPro.git
Import-Module ./UKGPro/UKGPro.psd1
```

Requires PowerShell 5.1+ or 7+.

## Installing on Windows (Mark-of-the-Web prompts)

When PowerShell modules land on a Windows machine from an internet source (`git pull` over HTTPS, downloaded ZIP, browser download), Windows attaches a hidden "Mark of the Web" (MOTW) marker to each file. Under the default execution policy, that triggers a `[R] Run once` / `[A] Always run` prompt the first time each `.ps1` file is imported — and because this module dot-sources one file per function, that means one prompt per cmdlet on every import.

Strip MOTW after each pull/download before importing:

```powershell
Get-ChildItem C:\path\to\UKGPro -Recurse | Unblock-File
Import-Module C:\path\to\UKGPro\UKGPro.psd1 -Force
```

`Unblock-File` removes only the MOTW alternate data stream — no execution-policy changes, no impact on other modules or system trust. Once the module is published to PowerShell Gallery (see Roadmap), `Install-Module UKGPro` / `Update-Module UKGPro` handles this automatically and no `Unblock-File` step is needed.

## Authentication

UKG Pro core REST APIs need **three** things on every request:

| Piece | What it is | Where to find it |
|---|---|---|
| Basic auth | Web-service-account username/password | Your UKG Pro web service account |
| `US-Customer-API-Key` | Tenant Customer API Key | System Configuration → Security → Web Services |
| `x-api-key` | User API Key from the same web service account | Shown next to the account username in Web Services |

The **hostname** is tenant-specific (assigned by UKG — see your Service Endpoint info).

```powershell
$cred = Get-Credential   # service-account username / password
Connect-UKGPro -Hostname 'service5.ultipro.com' `
               -Credential $cred `
               -CustomerApiKey 'your-customer-api-key' `
               -UserApiKey    'your-user-api-key'
```

Credentials are stored in a module-private session and attached automatically; you never pass them on individual calls.

## Cmdlets

| Cmdlet | Purpose |
|---|---|
| `Connect-UKGPro` | Open a session (Basic + two API-key headers) |
| `Disconnect-UKGPro` | Clear the session |
| `Get-UKGProEmploymentDetails` | Retrieve employment records, with filters |
| `Get-UKGProPersonDetails` | Retrieve person records (name / contact / address), by ID or email |
| `Get-UKGProOrgLevel` | Retrieve org-level configuration rows (level + code → description), unique lookup or filtered list |

## Examples

```powershell
# --- Employment details ---

# One employee, by ID
Get-UKGProEmploymentDetails -EmployeeId '000123'

# One employee, by email — resolves via /person-details (View-only) under
# the hood and then queries employment-details with the resolved ID.
Get-UKGProEmploymentDetails -EmailAddress 'alex.doe@example.com'

# Employees terminated in the last 30 days
Get-UKGProEmploymentDetails -TerminatedOn (Get-Date).AddDays(-30) -TerminatedOperator GreaterThan

# Terminations in a date range
Get-UKGProEmploymentDetails -TerminatedBetweenStart '2026-01-01' -TerminatedBetweenEnd '2026-03-31'

# Incremental sync: records changed in the last day
Get-UKGProEmploymentDetails -ChangedSince (Get-Date).AddHours(-24)

# --- Person details ---

# One person, by ID or by email — both hit /person-details directly (no
# extra resolver call; emailAddress is a native filter on this endpoint).
Get-UKGProPersonDetails -EmployeeId '000123'
Get-UKGProPersonDetails -EmailAddress 'alex.doe@example.com'

# Incremental sync of person records (name/address/contact changes)
Get-UKGProPersonDetails -ChangedSince (Get-Date).AddHours(-24)

# --- Org-level lookups (configuration/v1/org-levels) ---

# Unique lookup (level + code) — translate a code from an employment
# record (e.g. an employee's orgLevel2Code) into the human-readable name
(Get-UKGProOrgLevel -Level 2 -Code 'ACCT').description

# All codes at a specific level (client-side filtered — list endpoint
# doesn't accept a level query filter)
Get-UKGProOrgLevel -Level 2

# All active org-levels across every level (server-side filter)
Get-UKGProOrgLevel -IsActive $true
```

## Date filters

UKG Pro uses an unusual operator-prefixed date syntax (`dateOfTermination=>01-15-2026`). This module hides that: pass a normal `[datetime]` and pick a comparison via the matching `*-Operator` parameter (or the `*BetweenStart`/`*BetweenEnd` pair for ranges), and the correct `MM-DD-YYYY` operator string is built for you.

## Pagination

Handled automatically via `page` / `per_Page`. Use `-MaxResults` to cap total records and `-PageSize` to tune rows per request.

## Testing

```powershell
Invoke-Pester ./Tests
```

Tests mock the HTTP layer — no network or live tenant required.

## Roadmap

Additional read cmdlets across the `personnel/v1` and `configuration/v1` endpoint families: employee demographics, supervisor details, job history, employee status, jobs, locations, positions, company details, and more. Write cmdlets later where the API supports them and where they can be exposed cleanly. First-class PowerShell Gallery release once the read surface is broad enough to be useful out-of-the-box.

## License

MIT © Super Core Solutions LLC
