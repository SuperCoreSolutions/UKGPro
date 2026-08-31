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
        $expected = @('Connect-UKGPro', 'Disconnect-UKGPro', 'Get-UKGProEmploymentDetails')
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
