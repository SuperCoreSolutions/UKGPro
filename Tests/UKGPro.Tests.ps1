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
