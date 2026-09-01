# CLAUDE.md — UKGPro

Project context for Claude Code sessions. Read this first.

## What this is

A public PowerShell module wrapping the **UKG Pro HCM** REST API (Pro Employee
Data, `personnel/v1`). Companion to the separate **UKGHRSD** module (UKG HR
Service Delivery). They are intentionally separate repos/modules — different
platform, auth, and base URL. Do not merge them.

Owner: Don Sheehan / Super Core Solutions LLC.
Primary use case driving design: **offboarding / IAM automation** — pulling
employment status, termination dates, and supervisor info to drive downstream
deprovisioning.

Distribution goal: GitHub source repo + publish to the PowerShell Gallery.

## Current state (v0.1.0)

Scaffolded, imports clean, manifest valid, core logic unit-tested on
PowerShell 7.4.6. Deliberately minimal first pass: prove the auth + pagination
+ date-filter pattern with ONE real endpoint before expanding.

Built and working:
- `Connect-UKGPro` / `Disconnect-UKGPro`
- `Get-UKGProEmploymentDetails` (supports `-EmployeeId` or `-EmailAddress`;
  the latter resolves via `person-details` under the hood)
- `Get-UKGProPersonDetails` (supports `-EmployeeId` or `-EmailAddress`;
  both are native filters on this endpoint, no resolver hop)
- `Get-UKGProOrgLevel` (single cmdlet routes between the unique-lookup
  endpoint `/configuration/v1/org-levels/{level}/{code}` and the list
  endpoint `/configuration/v1/org-levels`; `-Level` alone triggers
  client-side filtering since the list endpoint has no level query param)
- `Get-UKGProJobGroup` (`/configuration/v1/jobgroup` — list only, filters
  by `-JobGroupCode` and `-CountryCode`)
- `Get-UKGProJob` (v2 — routes between `/configuration/v2/jobs` and
  `/configuration/v2/jobs/{code}`; UKG marks v1 as deprecated and v2 has
  strictly more capability including jobCode filter, pagination, and
  richer response fields)
- `Get-UKGProCompanyDetails` (`/configuration/v1/company-details` — list
  only, filters by `-CompanyId`, `-MasterCompanyId`, `-CompanyCode`,
  `-IsMasterCompany`)
- Private: `Invoke-UKGProRequest`, `ConvertTo-UKGProDateFilter`,
  `Get-UKGProErrorMessage`, `Resolve-UKGProEmployeeIdByEmail`
- Pester tests in `Tests/` (HTTP mocked; no live tenant needed)

NOT yet built: everything else (see Roadmap).

## Architecture / conventions (follow these when adding cmdlets)

- **One function per file.** Public cmdlets in `Public/`, internal helpers in
  `Private/`. `UKGPro.psm1` dot-sources both and exports only `Public/`.
- **Every new public cmdlet must be added to `FunctionsToExport` in
  `UKGPro.psd1`** — it's an explicit list, not a wildcard.
- **All API calls route through `Invoke-UKGProRequest`.** Don't call
  Invoke-RestMethod directly from a cmdlet. The wrapper owns auth headers,
  page/per_Page pagination, and error handling.
- Session is stored module-private in `$script:UKGProSession`. Never global.
- Keep comment-based help (`.SYNOPSIS`/`.EXAMPLE`) on every public cmdlet —
  the Gallery surfaces it and the owner prefers example-driven docs.
- **Every `Get-` cmdlet must be reachable with a View-only UKG service
  account.** When a `Get-` cmdlet needs to translate one identifier into
  another (e.g. email → employeeId for `Get-UKGProEmploymentDetails
  -EmailAddress`), always resolve via a `GET` endpoint such as
  `/person-details` or `/employee-demographic-details`. **Never** use
  `POST /personnel/v1/employee-ids` for a resolver — UKG's platform RBAC
  requires the "Add" role for any POST, which would force customers to
  provision a write-capable service account for a read cmdlet. Reserve
  POST/PATCH for actual write cmdlets (`New-`, `Set-`).

## Auth model (important — verified against the official spec)

UKG Pro core REST APIs require THREE things on every request, all attached by
`Invoke-UKGProRequest`:
1. `Authorization: Basic <base64 user:pass>` — web-service-account credential
   (ASCII-encoded — matches UKG's own examples and equivalent to UTF-8 for any
   ASCII-only service-account creds, which is the practical universe).
2. `US-Customer-API-Key` — tenant Customer API Key
   (System Configuration > Security > Web Services).
3. `x-api-key` — User API Key from the same web service account
   (shown next to the account username in Web Services).

**Header set verified empirically 2026-08-03 against a working live PowerShell
script.** The earlier `US-CLIENT-ID` (Primary Company Code) pattern was pulled
from a third-party OpenAPI mirror and did NOT match what real Pro tenants
accept. If you find UKG documentation suggesting `US-CLIENT-ID`, treat it as
the spec-vs-reality trap called out below and prefer the live-tenant behavior.

Base URL is **tenant-specific** (`{hostname}` in the spec) — `Connect-UKGPro`
takes `-Hostname`. Onboarding/recruiting APIs use a different auth (Auth Token),
but we are in the CORE bucket (personnel), so Basic + 2 keys is correct.

## Date-filter convention (unusual — don't re-derive)

UKG Pro puts the comparison operator INSIDE the value:
- less than:    `dateOfTermination=<MM-DD-YYYY`
- greater than: `dateOfTermination=>MM-DD-YYYY`
- equal:        `dateOfTermination=MM-DD-YYYY`
- between:      `dateOfTermination={MM-DD-YYYY,MM-DD-YYYY}`

`ConvertTo-UKGProDateFilter` builds the value string from a `[datetime]` + an
operator. Public cmdlets expose FRIENDLY params (e.g. `-TerminatedOn` +
`-TerminatedOperator`, `-TerminatedBetweenStart/-End`, `-ChangedSince`) that
call it. Add date filters this way — do not make users type the operator syntax.

## Pagination

`page` / `per_Page` (page-number based, NOT cursor — that's the HRSD module).
`Invoke-UKGProRequest` loops pages until a short page returns. `-MaxResults`
caps totals; `-PageSize` tunes rows/request.

## OPEN ITEMS — verify against a live tenant before publishing

1. **`employeeStatusCode` values are tenant-defined** and NOT enumerated in the
   spec. Pull real records to learn which codes mean terminated vs active, so
   status filtering is reliable. This gates any "find terminated employees"
   logic.
2. **Confirm UKG accepts the URL-encoded operator** (`%3E` for `>`) on the date
   filter. Formatting + encoding verified locally; only a live call proves the
   server accepts it.
3. General: `Get-UKGProEmploymentDetails -EmployeeId` and `-EmailAddress`
   verified live 2026-08-31. `Get-UKGProPersonDetails` shipped 2026-09-01;
   live end-to-end verification pending. `Get-UKGProOrgLevel` shipped
   2026-09-01 (module's first `configuration/v1/` endpoint); live
   end-to-end verification pending. `Get-UKGProJobGroup`, `Get-UKGProJob`
   (v2), and `Get-UKGProCompanyDetails` shipped 2026-09-01; live
   verification pending.

## Roadmap (next work, in rough priority for offboarding/IAM)

Add these `Get-` cmdlets (endpoints exist in the official "Pro Employee Data"
spec, `personnel/v1`):
- ~~`person-details` — name/contact~~ (shipped 2026-09-01 as `Get-UKGProPersonDetails`)
- `employee-demographic-details` — core identity
- `employee-supervisor-details` — reporting chain (offboarding routing)
- `employee-job-history-details` — job/status changes
- `integration/kronos/employee-status` — purpose-built status endpoint
- ~~`employee-ids` (POST) — ID lookup/cross-reference~~ (deliberately skipped;
  POST requires the "Add" role at the UKG RBAC layer even though functionally
  read — violates the View-only-Get- design principle above)

Later: write operations where the API supports them. Then PSGallery publish
(after live-tenant validation + a `PSScriptAnalyzer` pass).

The full official OpenAPI spec (50 endpoints) was used to build this; if
extending, get schemas from the real spec, not third-party mirrors (some public
UKG "specs" on the web are synthetically generated and untrustworthy).

## Build / test

- Requires PowerShell 5.1+ or 7+. Dev/validated on 7.4.6.
- Import: `Import-Module ./UKGPro.psd1 -Force`
- List cmdlets: `Get-Command -Module UKGPro`
- Manifest check: `Test-ModuleManifest ./UKGPro.psd1`
- Tests: `Invoke-Pester ./Tests` (install Pester 5+ first if needed)
- Before publishing: `Invoke-ScriptAnalyzer -Path . -Recurse` and fix warnings.

## Housekeeping

- `UKGPro.psd1` `ProjectUri`/`LicenseUri` currently point at
  `SuperCoreSolutions/UKGPro` — update if the real repo path differs.
- Add an MIT `LICENSE` file (README + manifest reference MIT).
- Never commit credentials. Use `Get-Credential` / env vars, never hardcoded
  secrets. `.gitignore` already excludes `*.secret` / `*.env`.
