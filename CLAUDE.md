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

## Current state (v0.2.1)

v0.2.1 (2026-09-02): 10 exported cmdlets, zero PSScriptAnalyzer findings under
the PSGallery ruleset, manifest URIs point at the real repo
(`SuperCoreSolutions/UKGPro` — LLC-org owned as of 2026-09-02),
Microsoft.PowerShell.SecretManagement declared as an optional external
dependency. **Published to PSGallery**:
https://www.powershellgallery.com/packages/UKGPro

Delta from v0.2.0 → v0.2.1: `Assert-UKGProSecretManagement` now catches
three fresh-machine setup failure modes (module missing, no vault
registered, no default vault) and throws copy-pasteable install /
`Register-SecretVault` / `Set-SecretVaultDefault` commands instead of
letting `Set-Secret`'s cryptic "no vault provided and there is no
default vault designated" error reach the user. Save/Update/Connect
callers all pass `-VaultName` through so the assertion can give the
most specific error possible. README `## Authentication` documents the
full one-time setup (install SecretStore + `Register-SecretVault
-DefaultVault` + optional `Set-SecretStoreConfiguration`). No cmdlet
signature changes, no breaking changes.

Built and working:
- `Connect-UKGPro` (three parameter sets: `Explicit` — original v0.1.0 flow;
  `-FromVault` — reads hostname + tenant API keys from SecretManagement,
  prompts for username/password via `Get-Credential` unless `-Credential`
  supplied; `-FromEnvironment` — reads all five values from env vars for
  CI / scheduled tasks) / `Disconnect-UKGPro`
- `Save-UKGProCredential` (one-time SecretManagement setup — writes
  hostname + two API keys as `UKGPro-Hostname` / `UKGPro-CustomerApiKey` /
  `UKGPro-UserApiKey`; NEVER stores username/password by design)
- `Update-UKGProCredential` (partial rotation — supports `-WhatIf` /
  `-Confirm`; throws if no rotation params supplied)
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
- **Auth ergonomics (three flows).** `Connect-UKGPro` has three parameter
  sets so users pick per situation:
  - **Explicit** (default): pass hostname, credential, and both API keys as
    parameters. Works without any external module dependency.
  - **`-FromVault`**: reads hostname + two API keys from Microsoft
    SecretManagement. Prompts for username/password via `Get-Credential`
    (or accepts `-Credential`).
  - **`-FromEnvironment`**: reads all five values from env vars
    (`UKGPRO_HOSTNAME`, `UKGPRO_USERNAME`, `UKGPRO_PASSWORD`,
    `UKGPRO_CUSTOMER_API_KEY`, `UKGPRO_USER_API_KEY`). CI/scheduled tasks.

  **Design principle: the vault flow deliberately does NOT persist the
  web-service-account username or password.** Only tenant-level API keys and
  hostname. Two reasons: (1) a compromised local vault reveals only tenant
  config, never the login secret; (2) operators uncomfortable persisting
  their account credential on a workstation still get the one-liner
  reconnect for the parts they were fine caching. The `-FromEnvironment`
  path accepts username/password because CI systems have their own secret
  stores (GitHub Actions secrets, Azure Pipelines vars) that inject env vars
  at runtime — different security model from a workstation vault.

  Reference implementations: `Public/Save-UKGProCredential.ps1`,
  `Public/Update-UKGProCredential.ps1`, and the three parameter sets in
  `Public/Connect-UKGPro.ps1`. SecretManagement is a soft dependency —
  checked at runtime via `Private/Assert-UKGProSecretManagement.ps1` with a
  copy-pasteable install command in the error message. Declared as an
  `ExternalModuleDependency` in the psd1 (informational; does not force
  install for users of the explicit-args flow).
- **Privacy defaults: `Get-` cmdlets that expose hard PII (SSN, DOB,
  home address, national IDs, protected-class demographics, health
  data) must default to a whitelisted subset of identity + work-safe
  fields and gate the full response behind `-IncludePII` + `-Force`.**
  The `-IncludePII` switch shows a `ShouldContinue` prompt in
  interactive sessions; `-Force` bypasses the prompt for scripts. The
  whitelist is applied client-side after `Invoke-UKGProRequest` returns
  — the full response still crosses the wire (UKG's endpoints don't
  support server-side field selection), so this is a "prevent
  accidental disclosure through logs/exports/Format-List" guardrail,
  not an end-to-end privacy guarantee. New response fields UKG adds
  later are hidden by default until explicitly added to the whitelist
  (safe-by-default = whitelist, not blacklist). Reference
  implementation: `Public/Get-UKGProPersonDetails.ps1`. Cmdlets returning
  only config / metadata (org-levels, jobs, job-groups, company-details)
  do NOT need this guard.

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

Later: write operations where the API supports them. A 1.0.0 release once
every shipped cmdlet has been live-tenant validated (the OPEN ITEMS section
above is the gating list).

The full official OpenAPI spec (50 endpoints) was used to build this; if
extending, get schemas from the real spec, not third-party mirrors (some public
UKG "specs" on the web are synthetically generated and untrustworthy).

## Build / test

- Requires PowerShell 5.1+ or 7+. Dev/validated on 7.4.6.
- Import: `Import-Module ./UKGPro.psd1 -Force`
- List cmdlets: `Get-Command -Module UKGPro`
- Manifest check: `Test-ModuleManifest ./UKGPro.psd1`
- Tests: `Invoke-Pester ./Tests` (install Pester 5+ first if needed)
- Before publishing: `Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSGallery`
  and fix warnings — or just let the build script do it (see below).

## Publish (PSGallery)

**Always publish through `Build/Publish-UKGProModule.ps1`.** Running
`Publish-Module` against the repo root ships CLAUDE.md, Tests/, and
other dev-only files (harmless but noisy — v0.2.0 was published this
way before the build script existed; see the file list on
PSGallery). The script stages a clean copy at `Build/staging/UKGPro/`
containing only the shipping surface — `.psd1` / `.psm1` / `LICENSE` /
`README.md` / `Public/*.ps1` / `Private/*.ps1` — validates the staged
manifest, runs Pester + PSScriptAnalyzer against that copy, and then
either prints the `Publish-Module` command (default, dry-run) or runs
it (with `-Publish -NuGetApiKey ...`).

```powershell
# Dry-run: stages + validates, prints the Publish-Module command.
./Build/Publish-UKGProModule.ps1

# Real publish (paste the PSGallery key, or pull from SecretManagement).
./Build/Publish-UKGProModule.ps1 -Publish -NuGetApiKey '<key>'
```

The staging directory (`Build/staging/`) is gitignored. Any change to
what should ship (new folder, new top-level file) goes in the
`$topLevelFiles` / subfolder loop inside the script — keep the
shipping list explicit, not "copy everything except X".

## Housekeeping

- `UKGPro.psd1` `ProjectUri`/`LicenseUri` and the actual repo location both
  live at `SuperCoreSolutions/UKGPro` (LLC GitHub org, confirmed 2026-09-02).
- MIT `LICENSE` file present at repo root.
- Never commit credentials. Use `Get-Credential` / env vars, never hardcoded
  secrets. `.gitignore` already excludes `*.secret` / `*.env`.
