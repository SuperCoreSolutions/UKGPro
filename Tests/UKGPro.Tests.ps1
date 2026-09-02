#Requires -Modules Pester

<#
    Pester tests for UKGPro.

    HTTP is mocked, so these run with no network and no real UKG tenant.
    Run:  Invoke-Pester ./Tests
#>

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $ModuleRoot 'UKGPro.psd1') -Force
}

Describe 'Module surface' {
    It 'exports the expected public functions' {
        $expected = @(
            'Connect-UKGPro', 'Disconnect-UKGPro',
            'Save-UKGProCredential', 'Update-UKGProCredential',
            'Get-UKGProEmploymentDetails', 'Get-UKGProPersonDetails',
            'Get-UKGProOrgLevel',
            'Get-UKGProJobGroup', 'Get-UKGProJob', 'Get-UKGProCompanyDetails'
        )
        (Get-Command -Module UKGPro).Name | Sort-Object | Should -Be ($expected | Sort-Object)
    }

    It 'has a valid manifest' {
        { Test-ModuleManifest (Join-Path (Split-Path -Parent $PSScriptRoot) 'UKGPro.psd1') } |
            Should -Not -Throw
    }
}

Describe 'ConvertTo-UKGProDateFilter' {
    InModuleScope UKGPro {
        It 'formats <Operator> correctly' -TestCases @(
            @{ Operator = 'GreaterThan'; Expected = '>07-01-2026' }
            @{ Operator = 'LessThan';    Expected = '<07-01-2026' }
            @{ Operator = 'EqualTo';     Expected = '07-01-2026'  }
        ) {
            param($Operator, $Expected)
            ConvertTo-UKGProDateFilter -Operator $Operator -Date ([datetime]'2026-07-01') |
                Should -Be $Expected
        }

        It 'formats a Between range' {
            ConvertTo-UKGProDateFilter -Operator Between `
                -RangeStart ([datetime]'2026-01-01') -RangeEnd ([datetime]'2026-03-31') |
                Should -Be '{01-01-2026,03-31-2026}'
        }

        It 'throws if Between is given without a range' {
            { ConvertTo-UKGProDateFilter -Operator Between -Date ([datetime]'2026-01-01') } |
                Should -Throw
        }
    }
}

Describe 'Get-UKGProEmploymentDetails without a session' {
    It 'throws a connect-first error' {
        Disconnect-UKGPro -ErrorAction SilentlyContinue
        { Get-UKGProEmploymentDetails -EmployeeId '1' } | Should -Throw '*Connect-UKGPro*'
    }
}

Describe 'Connect-UKGPro and request assembly' {
    InModuleScope UKGPro {
        It 'sends all three auth headers and the operator-prefixed date filter' {
            $sec  = ConvertTo-SecureString 'p@ss:word!' -AsPlainText -Force
            $cred = [System.Management.Automation.PSCredential]::new('svc_account', $sec)
            Connect-UKGPro -Hostname 'service5.ultipro.com' -Credential $cred `
                -CustomerApiKey 'CUSTKEY123' -UserApiKey 'USRKEY456'

            $script:captured = $null
            Mock Invoke-RestMethod {
                $script:captured = @{ Uri = $Uri; Headers = $Headers }
                return @()   # empty => single page
            }

            Get-UKGProEmploymentDetails -TerminatedOn ([datetime]'2026-07-01') `
                -TerminatedOperator GreaterThan | Out-Null

            $script:captured.Headers['US-Customer-API-Key'] | Should -Be 'CUSTKEY123'
            $script:captured.Headers['x-api-key']           | Should -Be 'USRKEY456'
            $script:captured.Headers['Authorization']       | Should -Match '^Basic '
            # Pester binds $Uri as [System.Uri]; ToString() shows the decoded form,
            # AbsoluteUri preserves the actual wire encoding (>  -> %3E).
            $script:captured.Uri.AbsoluteUri | Should -Match 'dateOfTermination=%3E07-01-2026'
        }

        It 'round-trips a password containing a colon in the Basic token' {
            $sec  = ConvertTo-SecureString 'p@ss:word!' -AsPlainText -Force
            $cred = [System.Management.Automation.PSCredential]::new('svc_account', $sec)
            Connect-UKGPro -Hostname 'h' -Credential $cred -CustomerApiKey 'k' -UserApiKey 'u'

            $decoded = [Text.Encoding]::ASCII.GetString(
                [Convert]::FromBase64String($script:UKGProSession.BasicToken))
            $decoded | Should -Be 'svc_account:p@ss:word!'
        }
    }
}

Describe 'Resolve-UKGProEmployeeIdByEmail' {
    InModuleScope UKGPro {
        BeforeEach {
            $sec  = ConvertTo-SecureString 'p' -AsPlainText -Force
            $cred = [pscredential]::new('u', $sec)
            Connect-UKGPro -Hostname 'h' -Credential $cred -CustomerApiKey 'k' -UserApiKey 'u'
        }

        It 'returns EmployeeId and CompanyId when person-details returns one match' {
            Mock Invoke-RestMethod {
                @([pscustomobject]@{ employeeId = '000123'; companyId = 'ACME'; emailAddress = 'a@x.com' })
            }
            $r = Resolve-UKGProEmployeeIdByEmail -EmailAddress 'a@x.com'
            $r.EmployeeId | Should -Be '000123'
            $r.CompanyId  | Should -Be 'ACME'
        }

        It 'throws "no employee found" when the response is empty' {
            Mock Invoke-RestMethod { @() }
            { Resolve-UKGProEmployeeIdByEmail -EmailAddress 'nobody@nowhere.example' } |
                Should -Throw "*No employee found*nobody@nowhere.example*"
        }

        It 'throws "multiple employees" when the response has more than one match' {
            Mock Invoke-RestMethod {
                @(
                    [pscustomobject]@{ employeeId = '1'; companyId = 'A' }
                    [pscustomobject]@{ employeeId = '2'; companyId = 'B' }
                )
            }
            { Resolve-UKGProEmployeeIdByEmail -EmailAddress 'dup@x.com' } |
                Should -Throw "*Multiple employees (2)*dup@x.com*disambiguate*"
        }
    }
}

Describe 'Get-UKGProEmploymentDetails -EmailAddress' {
    InModuleScope UKGPro {
        BeforeEach {
            $sec  = ConvertTo-SecureString 'p' -AsPlainText -Force
            $cred = [pscredential]::new('u', $sec)
            Connect-UKGPro -Hostname 'service5.ultipro.com' -Credential $cred `
                -CustomerApiKey 'CUSTKEY123' -UserApiKey 'USRKEY456'
            $script:calls = New-Object 'System.Collections.Generic.List[hashtable]'
        }

        It 'resolves the email via person-details, then queries employment-details with the resolved employeeId' {
            Mock Invoke-RestMethod {
                $call = @{ Uri = $Uri; Headers = $Headers }
                $script:calls.Add($call)
                if ($Uri.AbsoluteUri -match '/personnel/v1/person-details') {
                    return @([pscustomobject]@{ employeeId = 'EE999'; companyId = 'ACME' })
                }
                return @()  # employment-details: no records is fine, we only assert on the request
            }

            Get-UKGProEmploymentDetails -EmailAddress 'alex.doe@example.com' | Out-Null

            $script:calls.Count | Should -BeGreaterOrEqual 2
            $script:calls[0].Uri.AbsoluteUri | Should -Match '/personnel/v1/person-details\?.*emailAddress=alex\.doe%40example\.com'
            $script:calls[1].Uri.AbsoluteUri | Should -Match '/personnel/v1/employment-details\?.*employeeId=EE999'
            # Both calls carry the same auth headers.
            $script:calls[0].Headers['x-api-key'] | Should -Be 'USRKEY456'
            $script:calls[1].Headers['x-api-key'] | Should -Be 'USRKEY456'
        }

        It 'throws when both -EmailAddress and -EmployeeId are provided (no HTTP call made)' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri })
                @()
            }

            { Get-UKGProEmploymentDetails -EmailAddress 'a@x.com' -EmployeeId 'EE1' } |
                Should -Throw "*cannot be used together*"

            $script:calls.Count | Should -Be 0
        }
    }
}

Describe 'Get-UKGProPersonDetails' {
    InModuleScope UKGPro {
        BeforeEach {
            $sec  = ConvertTo-SecureString 'p' -AsPlainText -Force
            $cred = [pscredential]::new('u', $sec)
            Connect-UKGPro -Hostname 'service5.ultipro.com' -Credential $cred `
                -CustomerApiKey 'CUSTKEY123' -UserApiKey 'USRKEY456'
            $script:calls = New-Object 'System.Collections.Generic.List[hashtable]'
        }

        It '-EmployeeId hits /person-details with employeeId in the query and auth headers' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri; Headers = $Headers })
                @()
            }

            Get-UKGProPersonDetails -EmployeeId 'EE123' | Out-Null

            $script:calls.Count               | Should -Be 1
            $script:calls[0].Uri.AbsoluteUri  | Should -Match '/personnel/v1/person-details\?.*employeeId=EE123'
            $script:calls[0].Headers['x-api-key'] | Should -Be 'USRKEY456'
        }

        It '-EmailAddress passes the email as a native filter in a single call (no resolver hop)' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri; Headers = $Headers })
                @()
            }

            Get-UKGProPersonDetails -EmailAddress 'alex.doe@example.com' | Out-Null

            $script:calls.Count               | Should -Be 1
            $script:calls[0].Uri.AbsoluteUri  | Should -Match '/personnel/v1/person-details\?.*emailAddress=alex\.doe%40example\.com'
            $script:calls[0].Headers['x-api-key'] | Should -Be 'USRKEY456'
        }

        It '-ChangedSince adds the operator-prefixed dateTimeChanged filter' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri })
                @()
            }

            Get-UKGProPersonDetails -ChangedSince ([datetime]'2026-07-01') | Out-Null

            $script:calls.Count              | Should -Be 1
            # URL-encoded '>' is %3E; format is MM-DD-YYYY.
            $script:calls[0].Uri.AbsoluteUri | Should -Match 'dateTimeChanged=%3E07-01-2026'
        }

        It 'throws when both -EmailAddress and -EmployeeId are provided (no HTTP call made)' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri })
                @()
            }

            { Get-UKGProPersonDetails -EmailAddress 'a@x.com' -EmployeeId 'EE1' } |
                Should -Throw "*cannot be used together*"

            $script:calls.Count | Should -Be 0
        }

        It 'default call redacts PII fields, keeps whitelisted work-safe fields' {
            Mock Invoke-RestMethod {
                @([pscustomobject]@{
                    employeeId   = 'EE1'
                    companyId    = 'ACME'
                    firstName    = 'Alex'
                    lastName     = 'Doe'
                    emailAddress = 'alex.doe@example.com'
                    ssn          = '123-45-6789'
                    dateOfBirth  = '1990-01-01'
                    addressLine1 = '123 Fake St'
                    homePhone    = '555-1212'
                    gender       = 'F'
                })
            }

            $r = Get-UKGProPersonDetails -EmployeeId 'EE1'

            # Work-safe fields present
            $r.employeeId   | Should -Be 'EE1'
            $r.firstName    | Should -Be 'Alex'
            $r.emailAddress | Should -Be 'alex.doe@example.com'

            # PII fields stripped — Select-Object -Property adds NoteProperties
            # for the whitelisted set only, so anything not on the list won't
            # be a property on the returned object.
            $r.PSObject.Properties.Name -contains 'ssn'          | Should -BeFalse
            $r.PSObject.Properties.Name -contains 'dateOfBirth'  | Should -BeFalse
            $r.PSObject.Properties.Name -contains 'addressLine1' | Should -BeFalse
            $r.PSObject.Properties.Name -contains 'homePhone'    | Should -BeFalse
            $r.PSObject.Properties.Name -contains 'gender'       | Should -BeFalse
        }

        It '-IncludePII -Force returns the full record with no prompt' {
            Mock Invoke-RestMethod {
                @([pscustomobject]@{
                    employeeId   = 'EE1'
                    firstName    = 'Alex'
                    ssn          = '123-45-6789'
                    dateOfBirth  = '1990-01-01'
                    addressLine1 = '123 Fake St'
                })
            }

            $r = Get-UKGProPersonDetails -EmployeeId 'EE1' -IncludePII -Force

            $r.ssn          | Should -Be '123-45-6789'
            $r.dateOfBirth  | Should -Be '1990-01-01'
            $r.addressLine1 | Should -Be '123 Fake St'
            # And still keeps the work-safe fields.
            $r.firstName    | Should -Be 'Alex'
        }

        # NOTE: the -IncludePII (no -Force) prompt path uses PSCmdlet.ShouldContinue()
        # and does not test reliably under Pester (the non-interactive Pester host
        # interacts oddly with the interactive prompt machinery). This is a standard
        # PowerShell mechanism; the two tests above cover the redaction and bypass
        # paths that are module-specific. Prompt behavior is manually verified.
    }
}

Describe 'Get-UKGProOrgLevel' {
    InModuleScope UKGPro {
        BeforeEach {
            $sec  = ConvertTo-SecureString 'p' -AsPlainText -Force
            $cred = [pscredential]::new('u', $sec)
            Connect-UKGPro -Hostname 'service5.ultipro.com' -Credential $cred `
                -CustomerApiKey 'CUSTKEY123' -UserApiKey 'USRKEY456'
            $script:calls = New-Object 'System.Collections.Generic.List[hashtable]'
        }

        It '-Level + -Code hits the unique-lookup endpoint with no query params' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri; Headers = $Headers })
                [pscustomobject]@{ level = 2; code = 'ACCT'; description = 'Accounting' }
            }

            $r = Get-UKGProOrgLevel -Level 2 -Code 'ACCT'

            $script:calls.Count               | Should -Be 1
            $script:calls[0].Uri.AbsoluteUri  | Should -Match '/configuration/v1/org-levels/2/ACCT$'
            $script:calls[0].Uri.AbsoluteUri  | Should -Not -Match 'page='
            $script:calls[0].Uri.AbsoluteUri  | Should -Not -Match 'per_Page='
            $script:calls[0].Headers['x-api-key'] | Should -Be 'USRKEY456'
            $r.description                    | Should -Be 'Accounting'
        }

        It '-Code alone hits the list endpoint with code as a query filter' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri })
                @()
            }

            Get-UKGProOrgLevel -Code 'ACCT' | Out-Null

            $script:calls.Count              | Should -Be 1
            $script:calls[0].Uri.AbsoluteUri | Should -Match '/configuration/v1/org-levels\?.*code=ACCT'
            $script:calls[0].Uri.AbsoluteUri | Should -Not -Match '/org-levels/\d'
        }

        It '-IsActive $true is serialized as lowercase in the URL' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri })
                @()
            }

            Get-UKGProOrgLevel -IsActive $true | Out-Null

            $script:calls.Count              | Should -Be 1
            $script:calls[0].Uri.AbsoluteUri | Should -Match 'isActive=true'
        }

        It '-Level alone lists everything and filters to that level client-side' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri })
                @(
                    [pscustomobject]@{ level = 1; code = 'CO1';   description = 'Company 1' }
                    [pscustomobject]@{ level = 2; code = 'ACCT';  description = 'Accounting' }
                    [pscustomobject]@{ level = 2; code = 'SALES'; description = 'Sales' }
                    [pscustomobject]@{ level = 3; code = 'X';     description = 'X sub' }
                )
            }

            $r = Get-UKGProOrgLevel -Level 2

            $script:calls.Count              | Should -Be 1
            # Hits list endpoint (no /2 in path, no level= query)
            $script:calls[0].Uri.AbsoluteUri | Should -Match '/configuration/v1/org-levels$'
            $script:calls[0].Uri.AbsoluteUri | Should -Not -Match 'level='
            # Client-side filter keeps only level 2 rows
            ($r | Measure-Object).Count       | Should -Be 2
            ($r | ForEach-Object code)        | Should -Be @('ACCT', 'SALES')
        }

        It '-Level + other list filters composes server-side filter + client-side level filter' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri })
                @(
                    [pscustomobject]@{ level = 2; code = 'ACCT';  description = 'Accounting'; isActive = $true }
                    [pscustomobject]@{ level = 3; code = 'AR';    description = 'A/R';        isActive = $true }
                )
            }

            $r = Get-UKGProOrgLevel -Level 2 -IsActive $true

            $script:calls.Count              | Should -Be 1
            $script:calls[0].Uri.AbsoluteUri | Should -Match 'isActive=true'
            ($r | Measure-Object).Count       | Should -Be 1
            $r.code                           | Should -Be 'ACCT'
        }
    }
}

Describe 'Get-UKGProJobGroup' {
    InModuleScope UKGPro {
        BeforeEach {
            $sec  = ConvertTo-SecureString 'p' -AsPlainText -Force
            $cred = [pscredential]::new('u', $sec)
            Connect-UKGPro -Hostname 'service5.ultipro.com' -Credential $cred `
                -CustomerApiKey 'CUSTKEY123' -UserApiKey 'USRKEY456'
            $script:calls = New-Object 'System.Collections.Generic.List[hashtable]'
        }

        It 'no-args hits /configuration/v1/jobgroup with no filter query params' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri; Headers = $Headers })
                @()
            }

            Get-UKGProJobGroup | Out-Null

            $script:calls.Count               | Should -Be 1
            $script:calls[0].Uri.AbsoluteUri  | Should -Match '/configuration/v1/jobgroup\?'
            $script:calls[0].Uri.AbsoluteUri  | Should -Not -Match 'jobGroupCode='
            $script:calls[0].Uri.AbsoluteUri  | Should -Not -Match 'jobGroupCountryCode='
            $script:calls[0].Headers['x-api-key'] | Should -Be 'USRKEY456'
        }

        It '-JobGroupCode filters server-side' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri })
                @()
            }

            Get-UKGProJobGroup -JobGroupCode 'MGMT' | Out-Null

            $script:calls[0].Uri.AbsoluteUri | Should -Match 'jobGroupCode=MGMT'
        }

        It '-CountryCode maps to jobGroupCountryCode query param' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri })
                @()
            }

            Get-UKGProJobGroup -CountryCode 'US' | Out-Null

            $script:calls[0].Uri.AbsoluteUri | Should -Match 'jobGroupCountryCode=US'
        }
    }
}

Describe 'Get-UKGProJob' {
    InModuleScope UKGPro {
        BeforeEach {
            $sec  = ConvertTo-SecureString 'p' -AsPlainText -Force
            $cred = [pscredential]::new('u', $sec)
            Connect-UKGPro -Hostname 'service5.ultipro.com' -Credential $cred `
                -CustomerApiKey 'CUSTKEY123' -UserApiKey 'USRKEY456'
            $script:calls = New-Object 'System.Collections.Generic.List[hashtable]'
        }

        It '-Code alone hits the v2 unique-lookup endpoint with no query params' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri; Headers = $Headers })
                [pscustomobject]@{ jobCode = 'SWENG'; title = 'Software Engineer' }
            }

            $r = Get-UKGProJob -Code 'SWENG'

            $script:calls.Count               | Should -Be 1
            $script:calls[0].Uri.AbsoluteUri  | Should -Match '/configuration/v2/jobs/SWENG$'
            $script:calls[0].Uri.AbsoluteUri  | Should -Not -Match 'page='
            $script:calls[0].Uri.AbsoluteUri  | Should -Not -Match 'per_Page='
            $script:calls[0].Headers['x-api-key'] | Should -Be 'USRKEY456'
            $r.title | Should -Be 'Software Engineer'
        }

        It 'no-args hits the v2 list endpoint' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri })
                @()
            }

            Get-UKGProJob | Out-Null

            $script:calls[0].Uri.AbsoluteUri | Should -Match '/configuration/v2/jobs\?'
            $script:calls[0].Uri.AbsoluteUri | Should -Not -Match '/configuration/v2/jobs/'
        }

        It '-CountryCode + -IsActive filters compose server-side (isActive lowercase)' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri })
                @()
            }

            Get-UKGProJob -CountryCode 'US' -IsActive $true | Out-Null

            $script:calls[0].Uri.AbsoluteUri | Should -Match 'countryCode=US'
            $script:calls[0].Uri.AbsoluteUri | Should -Match 'isActive=true'
        }

        It '-Code combined with a list filter routes to the list endpoint (jobCode query)' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri })
                @()
            }

            Get-UKGProJob -Code 'SWENG' -IsActive $true | Out-Null

            # Composes as list-endpoint query; not the /jobs/SWENG detail path.
            $script:calls[0].Uri.AbsoluteUri | Should -Match '/configuration/v2/jobs\?'
            $script:calls[0].Uri.AbsoluteUri | Should -Match 'jobCode=SWENG'
            $script:calls[0].Uri.AbsoluteUri | Should -Match 'isActive=true'
        }
    }
}

Describe 'Get-UKGProCompanyDetails' {
    InModuleScope UKGPro {
        BeforeEach {
            $sec  = ConvertTo-SecureString 'p' -AsPlainText -Force
            $cred = [pscredential]::new('u', $sec)
            Connect-UKGPro -Hostname 'service5.ultipro.com' -Credential $cred `
                -CustomerApiKey 'CUSTKEY123' -UserApiKey 'USRKEY456'
            $script:calls = New-Object 'System.Collections.Generic.List[hashtable]'
        }

        It 'no-args hits /configuration/v1/company-details with no filter query params' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri; Headers = $Headers })
                @()
            }

            Get-UKGProCompanyDetails | Out-Null

            $script:calls.Count               | Should -Be 1
            $script:calls[0].Uri.AbsoluteUri  | Should -Match '/configuration/v1/company-details\?'
            $script:calls[0].Uri.AbsoluteUri  | Should -Not -Match 'companyId='
            $script:calls[0].Headers['x-api-key'] | Should -Be 'USRKEY456'
        }

        It '-CompanyId filters server-side' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri })
                @()
            }

            Get-UKGProCompanyDetails -CompanyId 'ACME' | Out-Null

            $script:calls[0].Uri.AbsoluteUri | Should -Match 'companyId=ACME'
        }

        It '-IsMasterCompany $true is serialized as lowercase' {
            Mock Invoke-RestMethod {
                $script:calls.Add(@{ Uri = $Uri })
                @()
            }

            Get-UKGProCompanyDetails -IsMasterCompany $true | Out-Null

            $script:calls[0].Uri.AbsoluteUri | Should -Match 'isMasterCompany=true'
        }
    }
}

Describe 'Save-UKGProCredential' {
    InModuleScope UKGPro {
        BeforeEach {
            $script:setSecretCalls = New-Object 'System.Collections.Generic.List[hashtable]'
            Mock Assert-UKGProSecretManagement { }
            Mock Set-Secret {
                $script:setSecretCalls.Add(@{
                    Name   = $Name
                    Secret = $Secret
                    Vault  = $Vault
                })
            }
        }

        It 'writes three secrets with the expected UKGPro-* names when all three params supplied' {
            Save-UKGProCredential -Hostname 'service5.ultipro.com' `
                                  -CustomerApiKey 'CUST123' `
                                  -UserApiKey 'USER456'

            $script:setSecretCalls.Count | Should -Be 3
            $names = $script:setSecretCalls | ForEach-Object Name | Sort-Object
            $names | Should -Be @('UKGPro-CustomerApiKey', 'UKGPro-Hostname', 'UKGPro-UserApiKey')
        }

        It 'passes -VaultName through to Set-Secret when supplied' {
            Save-UKGProCredential -Hostname 'h' -CustomerApiKey 'c' -UserApiKey 'u' `
                                  -VaultName 'UKGPro-Prod'

            $script:setSecretCalls | ForEach-Object { $_.Vault | Should -Be 'UKGPro-Prod' }
        }
    }
}

Describe 'Update-UKGProCredential' {
    InModuleScope UKGPro {
        BeforeEach {
            $script:setSecretCalls = New-Object 'System.Collections.Generic.List[hashtable]'
            Mock Assert-UKGProSecretManagement { }
            Mock Set-Secret {
                $script:setSecretCalls.Add(@{ Name = $Name })
            }
        }

        It 'passing only -CustomerApiKey writes exactly that one secret' {
            Update-UKGProCredential -CustomerApiKey 'NEWKEY'

            $script:setSecretCalls.Count      | Should -Be 1
            $script:setSecretCalls[0].Name    | Should -Be 'UKGPro-CustomerApiKey'
        }

        It 'passing all three params writes all three secrets' {
            Update-UKGProCredential -Hostname 'h' -CustomerApiKey 'c' -UserApiKey 'u'

            $script:setSecretCalls.Count | Should -Be 3
        }

        It 'passing no params throws before touching the vault' {
            { Update-UKGProCredential } | Should -Throw "*requires at least one*"
            $script:setSecretCalls.Count | Should -Be 0
        }
    }
}

Describe 'Connect-UKGPro alternative parameter sets' {
    InModuleScope UKGPro {
        Context '-FromEnvironment' {
            BeforeEach {
                $env:UKGPRO_HOSTNAME         = 'service5.ultipro.com'
                $env:UKGPRO_USERNAME         = 'svc_env'
                $env:UKGPRO_PASSWORD         = 'p@ss!'
                $env:UKGPRO_CUSTOMER_API_KEY = 'CUSTENV'
                $env:UKGPRO_USER_API_KEY     = 'USERENV'
                $script:UKGProSession        = $null
            }
            AfterEach {
                Remove-Item Env:UKGPRO_HOSTNAME, Env:UKGPRO_USERNAME, Env:UKGPRO_PASSWORD, `
                            Env:UKGPRO_CUSTOMER_API_KEY, Env:UKGPRO_USER_API_KEY `
                            -ErrorAction SilentlyContinue
            }

            It 'reads five env vars and populates the module-private session' {
                Connect-UKGPro -FromEnvironment

                $script:UKGProSession                 | Should -Not -BeNullOrEmpty
                $script:UKGProSession.Hostname        | Should -Be 'service5.ultipro.com'
                $script:UKGProSession.Username        | Should -Be 'svc_env'
                $script:UKGProSession.CustomerApiKey  | Should -Be 'CUSTENV'
                $script:UKGProSession.UserApiKey      | Should -Be 'USERENV'
                $script:UKGProSession.BasicToken      | Should -Not -BeNullOrEmpty
            }

            It 'throws with a helpful message listing missing env vars' {
                Remove-Item Env:UKGPRO_PASSWORD, Env:UKGPRO_USER_API_KEY -ErrorAction SilentlyContinue

                { Connect-UKGPro -FromEnvironment } |
                    Should -Throw "*UKGPRO_PASSWORD*UKGPRO_USER_API_KEY*"
            }
        }

        Context '-FromVault' {
            BeforeEach {
                Mock Assert-UKGProSecretManagement { }
                Mock Get-Secret {
                    switch ($Name) {
                        'UKGPro-Hostname'       { 'service5.ultipro.com' }
                        'UKGPro-CustomerApiKey' { 'CUSTVAULT' }
                        'UKGPro-UserApiKey'     { 'USERVAULT' }
                    }
                }
                $script:UKGProSession = $null
                $script:getCredentialCallCount = 0
                Mock Get-Credential {
                    $script:getCredentialCallCount++
                    $sec = ConvertTo-SecureString 'p@ss!' -AsPlainText -Force
                    [pscredential]::new('svc_vault_prompt', $sec)
                }
            }

            It 'reads three vault secrets and uses supplied -Credential without prompting' {
                $sec  = ConvertTo-SecureString 'p@ss!' -AsPlainText -Force
                $cred = [pscredential]::new('svc_vault_explicit', $sec)

                Connect-UKGPro -FromVault -Credential $cred

                $script:UKGProSession.Hostname        | Should -Be 'service5.ultipro.com'
                $script:UKGProSession.CustomerApiKey  | Should -Be 'CUSTVAULT'
                $script:UKGProSession.UserApiKey      | Should -Be 'USERVAULT'
                $script:UKGProSession.Username        | Should -Be 'svc_vault_explicit'
                $script:getCredentialCallCount        | Should -Be 0
            }

            It 'prompts via Get-Credential when -Credential is omitted' {
                Connect-UKGPro -FromVault

                $script:UKGProSession.Username | Should -Be 'svc_vault_prompt'
                $script:getCredentialCallCount | Should -Be 1
            }
        }
    }
}
