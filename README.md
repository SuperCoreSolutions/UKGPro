# UKGPro

A general-purpose PowerShell module wrapping the **UKG Pro HCM** REST API. Provides typed `Get-` cmdlets for the `personnel/v1` (employment records, person details) and `configuration/v1` (org-levels, more to come) endpoint families, with a shared authentication, pagination, and date-filter layer so callers work with objects and parameters instead of URL strings and query encoding.

Common use cases include HR data extracts, employee-record reporting, IAM provisioning/deprovisioning workflows, and one-off lookups from an interactive PowerShell session — but nothing in the module is tied to any single workflow. Any script that needs to read UKG Pro data can use it.

Companion to the separate [UKGHRSD](../UKGHRSD) module (which covers UKG HR Service Delivery). The two are intentionally separate: different platform, authentication, and base URL.

> Status: v0.2.1 — [live on PowerShell Gallery](https://www.powershellgallery.com/packages/UKGPro). Ten `Get-` and connect cmdlets across the `personnel/v1` and `configuration/v1` endpoint families, secure-by-default PII redaction, optional SecretManagement-backed auth for one-line reconnects.

## Install

```powershell
# From PowerShell Gallery
Install-Module UKGPro -Scope CurrentUser

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

Three ways to connect, pick whichever fits your setup:

### 1. Explicit (default) — pass everything each session

```powershell
$cred = Get-Credential   # service-account username / password
Connect-UKGPro -Hostname 'service5.ultipro.com' `
               -Credential $cred `
               -CustomerApiKey 'your-customer-api-key' `
               -UserApiKey    'your-user-api-key'
```

### 2. Vault-backed — save the tenant config once, reconnect with one line

Uses Microsoft's [SecretManagement](https://learn.microsoft.com/powershell/utility-modules/secretmanagement/overview) framework. It's the SecretManagement API + a vault provider (`SecretStore` is Microsoft's default cross-platform choice) + a registered vault marked as default. The `Save-UKGProCredential` / `Update-UKGProCredential` / `Connect-UKGPro -FromVault` cmdlets detect each of those pieces and throw a copy-pasteable setup command if anything is missing, so you'll be prompted through the right install step whenever you run one on a fresh machine.

**One-time machine setup:**

```powershell
# 1. Install the SecretManagement API + Microsoft's default vault provider.
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
Install-Module Microsoft.PowerShell.SecretStore        -Scope CurrentUser

# 2. Register SecretStore as a vault, mark it as the default.
Register-SecretVault -Name SecretStore `
                     -ModuleName Microsoft.PowerShell.SecretStore `
                     -DefaultVault

# 3. (Optional) Configure vault password / timeout up front instead of
#    being prompted on the first Set-Secret call. Skip to be prompted
#    lazily.
Set-SecretStoreConfiguration
```

The vault password is separate from your UKG credential — it unlocks the local store on subsequent sessions. Prefer another SecretManagement backend? Install that vault module in step 1 (e.g. [`SecretManagement.Keychain`](https://www.powershellgallery.com/packages/SecretManagement.KeyChain) for macOS, `Microsoft.PowerShell.SecretManagement.AzKeyVault` for Azure) and register it in step 2 instead — everything downstream still works.

**One-time module setup** — writes hostname + both API keys to the default vault:

```powershell
Save-UKGProCredential -Hostname 'service5.ultipro.com' `
                      -CustomerApiKey 'your-customer-api-key' `
                      -UserApiKey    'your-user-api-key'
```

**Every subsequent session:**

```powershell
Connect-UKGPro -FromVault    # prompts for username/password only
```

**Design note: the vault deliberately does NOT store the web-service-account username or password.** Only the tenant-level API keys and hostname are persisted. The account credential is prompted at connect time (or supplied via `-Credential` if scripting). Rationale: a compromised local vault reveals only tenant config, never the login secret; and operators uncomfortable persisting their credentials on a workstation still get the one-liner reconnect experience for the parts they were fine caching.

Rotate a leaked key without re-entering the others:

```powershell
Update-UKGProCredential -CustomerApiKey '<new-key>'
```

### 3. Environment variables — for CI, scheduled tasks, containers

For fully non-interactive scenarios where prompts don't work. The CI system's own secret store (GitHub Actions, Azure Pipelines vars, etc.) is the actual keeper of the values.

```powershell
$env:UKGPRO_HOSTNAME           = 'service5.ultipro.com'
$env:UKGPRO_USERNAME           = 'svc_account'
$env:UKGPRO_PASSWORD           = 'redacted'
$env:UKGPRO_CUSTOMER_API_KEY   = 'your-customer-api-key'
$env:UKGPRO_USER_API_KEY       = 'your-user-api-key'

Connect-UKGPro -FromEnvironment
```

Credentials are stored in a module-private session and attached automatically to every subsequent request; you never pass them on individual `Get-*` calls.

## Cmdlets

| Cmdlet | Purpose |
|---|---|
| [`Connect-UKGPro`](#connect-ukgpro) | Open a session (Basic + two API-key headers). Three flows: explicit, `-FromVault`, `-FromEnvironment` |
| [`Disconnect-UKGPro`](#disconnect-ukgpro) | Clear the session |
| [`Save-UKGProCredential`](#save-ukgprocredential) | One-time SecretManagement setup — writes hostname + tenant API keys (never username/password) |
| [`Update-UKGProCredential`](#update-ukgprocredential) | Partial rotation of stored secrets — rotate a leaked API key without re-entering everything |
| [`Get-UKGProEmploymentDetails`](#get-ukgproemploymentdetails) | Retrieve employment records, with filters |
| [`Get-UKGProPersonDetails`](#get-ukgpropersondetails) | Retrieve person records (name / contact / address), by ID or email |
| [`Get-UKGProOrgLevel`](#get-ukgproorglevel) | Retrieve org-level configuration rows (level + code → description), unique lookup or filtered list |
| [`Get-UKGProJobGroup`](#get-ukgprojobgroup) | Retrieve job-group configuration rows (jobGroupCode → description) |
| [`Get-UKGProJob`](#get-ukgprojob) | Retrieve job configuration rows (via v2 endpoints), unique lookup or filtered list |
| [`Get-UKGProCompanyDetails`](#get-ukgprocompanydetails) | Retrieve company records (name, address, tax ID, org-level codes) for master and component companies |

Every cmdlet also gets full comment-based help — `Get-Help <Cmdlet> -Full` in PowerShell shows synopsis, per-parameter descriptions, and worked examples.

### Connect-UKGPro

Opens an authenticated session and stores credentials in a module-private variable so subsequent `Get-*` cmdlets can reuse them. Three parameter sets:

**Explicit set (default):** pass everything as parameters.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-Hostname` | `string` | yes | Tenant service endpoint host, with or without `https://`. |
| `-Credential` | `PSCredential` | yes | Web-service-account username + password. Use `Get-Credential`. |
| `-CustomerApiKey` | `string` | yes | Tenant Customer API Key (sent as `US-Customer-API-Key`). |
| `-UserApiKey` | `string` | yes | User API Key from the same web service account (sent as `x-api-key`). |

**FromVault set:** pull hostname + two API keys from a SecretManagement vault (previously populated with `Save-UKGProCredential`).

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-FromVault` | `switch` | yes | Selects this parameter set. |
| `-VaultName` | `string` | no | Specific vault to read from. Omit to use the default vault. |
| `-Credential` | `PSCredential` | no | Web-service-account credential. Omit to be prompted via `Get-Credential`. |

**FromEnvironment set:** read all five values from env vars, for CI / scheduled tasks / containers.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-FromEnvironment` | `switch` | yes | Selects this parameter set. Reads `UKGPRO_HOSTNAME`, `UKGPRO_USERNAME`, `UKGPRO_PASSWORD`, `UKGPRO_CUSTOMER_API_KEY`, `UKGPRO_USER_API_KEY`. Throws with a list of missing vars if any are absent. |

Common to all sets:

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-PassThru` | `switch` | no | Return a redacted session summary (BaseUrl, Username, ConnectedAt). Secrets are never included. |

### Disconnect-UKGPro

Clears the module-private session. UKG Pro uses stateless per-request auth, so this only clears local credentials — no server call.

*No parameters.*

### Save-UKGProCredential

Writes hostname + tenant API keys to a SecretManagement vault under `UKGPro-Hostname`, `UKGPro-CustomerApiKey`, `UKGPro-UserApiKey`. Overwrites existing values. Requires `Microsoft.PowerShell.SecretManagement`.

**Never stores the web-service-account username or password** — those are always supplied at connect time.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-Hostname` | `string` | yes | Tenant service endpoint host. |
| `-CustomerApiKey` | `string` | yes | Tenant Customer API Key. Stored as `SecureString`. |
| `-UserApiKey` | `string` | yes | User API Key. Stored as `SecureString`. |
| `-VaultName` | `string` | no | Specific vault to write to. Omit to use the default vault. |

### Update-UKGProCredential

Partial rotation — writes only the secrets whose parameters were supplied; the rest remain untouched. At least one of `-Hostname`, `-CustomerApiKey`, `-UserApiKey` must be supplied (throws otherwise). Supports `-WhatIf` and `-Confirm`.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-Hostname` | `string` | no | New hostname (e.g. tenant migration). |
| `-CustomerApiKey` | `string` | no | New Customer API Key (e.g. key rotation). |
| `-UserApiKey` | `string` | no | New User API Key. |
| `-VaultName` | `string` | no | Specific vault (should match the vault Save-UKGProCredential wrote to). |

### Get-UKGProEmploymentDetails

Wraps `GET /personnel/v1/employment-details`. All filters are optional and applied server-side (except `-EmailAddress`, which is resolved to an ID via `person-details` first, then applied — see the [ID vs email note](#get-ukgproemploymentdetails-notes) below). Results paginate automatically unless `-MaxResults` caps them.

| Parameter | Type | Description |
|---|---|---|
| `-CompanyId` | `string` | Filter by company identifier. |
| `-EmployeeId` | `string` | Filter by employee identifier. Mutually exclusive with `-EmailAddress`. |
| `-EmailAddress` | `string` | Filter by the employee's UKG-registered email. Resolved via `/person-details` under the hood. Mutually exclusive with `-EmployeeId`. |
| `-EmployeeNumber` | `string` | Filter by employee number. |
| `-EmployeeStatusCode` | `string` | Filter by employee status code (tenant-defined, e.g. `A` for active). |
| `-EmployeeTypeCode` | `string` | Filter by employee type code. |
| `-SupervisorId` | `string` | Filter by supervisor ID. |
| `-JobTitle` | `string` | Filter by job title. |
| `-PrimaryJobCode` | `string` | Filter by primary job code. |
| `-PrimaryWorkLocationCode` | `string` | Filter by primary work location code. |
| `-TerminatedOn` | `datetime` | Termination date filter. Pair with `-TerminatedOperator`. |
| `-TerminatedOperator` | `LessThan` \| `GreaterThan` \| `EqualTo` | Comparison for `-TerminatedOn`. Default: `GreaterThan`. |
| `-TerminatedBetweenStart` | `datetime` | Inclusive range start (use with `-TerminatedBetweenEnd`). |
| `-TerminatedBetweenEnd` | `datetime` | Inclusive range end (use with `-TerminatedBetweenStart`). |
| `-ChangedSince` | `datetime` | Return records whose `dateTimeChanged` is greater than this — for incremental syncs. |
| `-MaxResults` | `int` | Cap total records across all pages. `0` = no cap. Default: `0`. |
| `-PageSize` | `int` | Rows per page. Default: `100`. |

<a id="get-ukgproemploymentdetails-notes"></a>
**Note on `-EmailAddress`:** the employment-details endpoint doesn't accept `emailAddress` as a query parameter, so the module transparently resolves email → `employeeId` via `GET /personnel/v1/person-details` (a View-only lookup), then queries employment-details with the resolved ID. Two HTTP calls, one cmdlet invocation.

### Get-UKGProPersonDetails

Wraps `GET /personnel/v1/person-details`. Unlike employment-details, `emailAddress` is a native filter on this endpoint — both `-EmployeeId` and `-EmailAddress` translate directly into single server-side requests with no resolver hop.

**Privacy defaults (secure-by-default):** the raw API response contains substantial PII (SSN, `dateOfBirth`, full home address, national IDs, protected-class demographics, COBRA status, I-9 documents, health data). By default this cmdlet strips everything except a whitelisted set of identity + work-safe fields (`personId`, `employeeId`, `companyId`, `userName`, first/middle/last name, `preferredName`, `namePrefixCode`, `nameSufixCode`, `emailAddress`, `datetimeCreated`, `datetimeChanged`, `integrationRecordId`). Pass `-IncludePII` to opt in to the full response — an interactive session will prompt for confirmation; pass `-Force` to skip the prompt in scripts. The full response is always fetched from UKG; the whitelist is applied client-side to prevent accidental disclosure through logs, exports, or `Format-List` output.

| Parameter | Type | Description |
|---|---|---|
| `-EmployeeId` | `string` | Filter by employee identifier. Mutually exclusive with `-EmailAddress`. |
| `-EmailAddress` | `string` | Filter by email — passed to the endpoint's native `emailAddress` query param. Mutually exclusive with `-EmployeeId`. |
| `-CompanyId` | `string` | Narrow to one company (multi-company tenants). |
| `-LastName` | `string` | Filter by last name. The endpoint accepts `*` as a wildcard (e.g. `Smi*` matches `Smith`, `Smiley`). |
| `-ChangedSince` | `datetime` | Return records whose `dateTimeChanged` is greater than this — for incremental syncs. |
| `-MaxResults` | `int` | Cap total records across all pages. `0` = no cap. Default: `0`. |
| `-PageSize` | `int` | Rows per page. Default: `100`. |
| `-IncludePII` | `switch` | Return the full API response including SSN, DOB, home address, national IDs, and other PII fields. Without this switch only the whitelisted fields listed above are returned. |
| `-Force` | `switch` | Skip the confirmation prompt that `-IncludePII` normally shows. Use in scripts and scheduled tasks. |

### Get-UKGProOrgLevel

Routes automatically between the unique-lookup endpoint (`GET /configuration/v1/org-levels/{level}/{code}`) and the list endpoint (`GET /configuration/v1/org-levels`) based on which parameters are supplied.

| Parameter | Type | Description |
|---|---|---|
| `-Level` | `int` | Org level number (typically 1–4). Alone: lists all codes at that level (client-side filtered — see note below). With `-Code`: unique server-side lookup. |
| `-Code` | `string` | Org code (e.g. `ACCT`). Alone: list filtered by code (may return matches across multiple levels). With `-Level`: unique lookup. |
| `-LevelDescription` | `string` | Filter list by the level's description name (e.g. `Department`). |
| `-BudgetGroup` | `string` | Filter list by budget group. |
| `-ReportingCategory` | `string` | Filter list by reporting category code. |
| `-IsActive` | `bool` | Filter list by active/inactive status. Serialized to the URL as lowercase (`true` / `false`). |

**Note on `-Level` alone:** the list endpoint has no `level` query parameter, so the module fetches the full list and filters client-side by level. Cheap in practice — org-levels tables are typically small (dozens to a few hundred rows total, and the endpoint doesn't paginate). Composes with server-side filters, e.g. `-Level 2 -IsActive $true` sends `isActive=true` server-side then filters level 2 client-side.

### Get-UKGProJobGroup

Wraps `GET /configuration/v1/jobgroup`. Resolves `jobGroupCode` values from employment records into descriptions, or lists job groups filtered by country.

| Parameter | Type | Description |
|---|---|---|
| `-JobGroupCode` | `string` | Filter by a specific job group code (e.g. `MGMT`). |
| `-CountryCode` | `string` | Filter by country. Maps to the endpoint's `jobGroupCountryCode` query parameter. |
| `-MaxResults` | `int` | Cap total records across all pages. `0` = no cap. Default: `0`. |
| `-PageSize` | `int` | Rows per page. Default: `100`. |

### Get-UKGProJob

Routes between `GET /configuration/v2/jobs` (list) and `GET /configuration/v2/jobs/{code}` (unique lookup). Uses v2 — UKG marks v1 as deprecated and v2 has more capability (jobCode as a query filter, pagination, richer response including `longDescription`, `jobGroup`, `flsaTypeCode`, `jobEE0Category`, `workEnvironmentDesc`).

| Parameter | Type | Description |
|---|---|---|
| `-Code` | `string` | Job code (e.g. `SWENG`). Alone: unique-lookup endpoint, returns a single job. Combined with other filters: applied as a `jobCode` filter on the list endpoint. |
| `-CountryCode` | `string` | Filter list by country code. |
| `-IsActive` | `bool` | Filter list by active/inactive. Serialized to the URL as lowercase (`true` / `false`). |
| `-MaxResults` | `int` | Cap total records across all pages. `0` = no cap. Default: `0`. |
| `-PageSize` | `int` | Rows per page. Default: `100`. |

**Note on Jobs v2 pagination:** UKG's v2 spec uses `per_page` (lowercase 'p') while `Invoke-UKGProRequest` sends `per_Page`. The module's pagination loop still terminates correctly because it detects the last (short) page from the response count, not from the requested page size — so this inconsistency is silently handled.

### Get-UKGProCompanyDetails

Wraps `GET /configuration/v1/company-details`. Returns full company records for master and component companies — useful for multi-company tenants or resolving a `companyId` / `companyCode` from an employment record.

| Parameter | Type | Description |
|---|---|---|
| `-CompanyId` | `string` | Filter by 5-character UKG Pro HCM CompanyID. |
| `-MasterCompanyId` | `string` | Filter by 5-character Master CompanyID. |
| `-CompanyCode` | `string` | Filter by 5-character Company Code. |
| `-IsMasterCompany` | `bool` | Filter to master companies only (or component companies only if `$false`). Serialized to the URL as lowercase. |
| `-MaxResults` | `int` | Cap total records across all pages. `0` = no cap. Default: `0`. |
| `-PageSize` | `int` | Rows per page. Default: `100`. |

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
# Secure-by-default: only identity + work-safe fields (no SSN / DOB / address).
Get-UKGProPersonDetails -EmployeeId '000123'
Get-UKGProPersonDetails -EmailAddress 'alex.doe@example.com'

# Opt in to full PII (interactive session prompts; -Force skips the prompt).
Get-UKGProPersonDetails -EmployeeId '000123' -IncludePII -Force |
    Select-Object employeeId, ssn, dateOfBirth, addressLine1

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

# --- Job groups (configuration/v1/jobgroup) ---

# Resolve a jobGroupCode from an employment record into a description
(Get-UKGProJobGroup -JobGroupCode 'MGMT').jobGroupCodeDescription

# All job groups in a specific country
Get-UKGProJobGroup -CountryCode 'US'

# --- Jobs (configuration/v2/jobs) ---

# Unique lookup — full job configuration by code
Get-UKGProJob -Code 'SWENG'

# All active US jobs
Get-UKGProJob -CountryCode 'US' -IsActive $true

# --- Company details (configuration/v1/company-details) ---

# Every company (master and component) in the tenant
Get-UKGProCompanyDetails

# Resolve a specific companyId (from an employment record) into the full record
Get-UKGProCompanyDetails -CompanyId 'ACME'

# Only master companies
Get-UKGProCompanyDetails -IsMasterCompany $true
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
