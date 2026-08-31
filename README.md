# UKGPro

A PowerShell module for the **UKG Pro HCM** REST API (Pro Employee Data / `personnel/v1`).

Its first focus is retrieving **employment details** — status, job, supervisor, and key dates like termination — for HR, **offboarding**, and IAM automation. It's a companion to the separate [UKGHRSD](../UKGHRSD) module (which covers UKG HR Service Delivery). The two are intentionally separate: different platform, auth, and base URL.

> Status: early scaffold (v0.1.0). `Connect` + one `Get-` cmdlet to prove the auth/pagination pattern; more employee-data cmdlets to follow.

## Install

```powershell
# From PowerShell Gallery (once published)
Install-Module UKGPro

# Or from source
git clone https://github.com/SuperCoreSolutions/UKGPro.git
Import-Module ./UKGPro/UKGPro.psd1
```

Requires PowerShell 5.1+ or 7+.

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

## Examples

```powershell
# One employee
Get-UKGProEmploymentDetails -EmployeeId '000123'

# Offboarding candidates: terminated in the last 30 days
Get-UKGProEmploymentDetails -TerminatedOn (Get-Date).AddDays(-30) -TerminatedOperator GreaterThan

# Terminations in a date range
Get-UKGProEmploymentDetails -TerminatedBetweenStart '2026-01-01' -TerminatedBetweenEnd '2026-03-31'

# Incremental sync: records changed in the last day
Get-UKGProEmploymentDetails -ChangedSince (Get-Date).AddHours(-24)
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

Additional read cmdlets aligned to offboarding/IAM: employee demographics, person details, supervisor details, job history, and employee status. Write operations later where the API supports them.

## License

MIT © Super Core Solutions LLC
