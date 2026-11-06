BeforeAll {
    . "$PSScriptRoot/../pack/tests/Test.MP.AIGOV.1019.ps1"
}

Describe 'Test-MPAIGOV1019' {
    BeforeEach {
        Mock Add-MtTestResultDetail {}
    }

    It 'passes when there are no agent identities' {
        Mock Invoke-MtGraphRequest { @() }

        $result = Test-MPAIGOV1019

        $result | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $Severity -eq $null }
    }

    It 'passes when agent identities exist but none has a user-consented grant' {
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/microsoft.graph.agentIdentity' } {
            @([pscustomobject]@{ id = 'agent-1'; displayName = 'Quiet agent'; appId = 'app-1' })
        }
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'oauth2PermissionGrants' } { @() }

        $result = Test-MPAIGOV1019

        $result | Should -Be $true
    }

    It 'reports Medium when an agent has a user-consented grant with only ordinary scopes' {
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/microsoft.graph.agentIdentity' } {
            @([pscustomobject]@{ id = 'agent-1'; displayName = 'Agent one'; appId = 'app-1' })
        }
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'oauth2PermissionGrants' } {
            @(
                [pscustomobject]@{ principalId = 'user-1'; scope = 'Mail.Read Calendars.Read' }
            )
        }

        $result = Test-MPAIGOV1019

        $result | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'Medium' -and $Result -match 'agent-1'
        }
    }

    It 'reports High when a granted scope is on the high-risk list' {
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/microsoft.graph.agentIdentity' } {
            @([pscustomobject]@{ id = 'agent-1'; displayName = 'Risky agent'; appId = 'app-1' })
        }
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'oauth2PermissionGrants' } {
            @(
                [pscustomobject]@{ principalId = 'user-1'; scope = 'Mail.Read Policy.ReadWrite.ConditionalAccess' }
            )
        }

        $result = Test-MPAIGOV1019

        $result | Should -Be $false
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Severity -eq 'High' -and $Result -match 'Policy.ReadWrite.ConditionalAccess'
        }
    }

    It 'counts and excludes an agent whose grant read fails, without failing the whole test' {
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/microsoft.graph.agentIdentity' } {
            @(
                [pscustomobject]@{ id = 'agent-1'; displayName = 'Broken agent'; appId = 'app-1' }
            )
        }
        Mock Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'oauth2PermissionGrants' } {
            throw 'Simulated grant-read failure'
        }

        $result = Test-MPAIGOV1019

        $result | Should -Be $true
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter {
            $Result -match '1 agent identity\(ies\) could not be evaluated'
        }
    }

    It 'skips with NotAuthorized on a 403 from the agent identity list call' {
        Mock Invoke-MtGraphRequest { throw 'Request failed: 403 Forbidden' }

        $result = Test-MPAIGOV1019

        $result | Should -Be $null
        Should -Invoke Add-MtTestResultDetail -Times 1 -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
    }
}

Describe 'Test-MPAIGOV1019 high-risk scope list drift check' {
    It 'matches the pinned hash so an edit to $HighRiskScopes is never silent' {
        # Keep this test's expected hash, and the pinned Maester commit cited in the function's
        # .LINK/.DESCRIPTION, in sync with each other. If this test fails after a deliberate edit
        # to $HighRiskScopes in Test.MP.AIGOV.1019.ps1, re-verify the new list against Maester's
        # current Get-MtEntraAgentHighRiskGraphPermissionFinding.ps1 source, update the pinned
        # commit SHA in both .LINK entries and the .DESCRIPTION, and only then update this hash.
        $scriptPath = Join-Path $PSScriptRoot '../pack/tests/Test.MP.AIGOV.1019.ps1'
        $raw = Get-Content -Path $scriptPath -Raw

        if ($raw -notmatch '(?s)\$HighRiskScopes\s*=\s*(@\([^)]*\))') {
            throw "Could not locate the `$HighRiskScopes array literal in $scriptPath."
        }
        $arrayLiteral = $Matches[1]
        # Safe to evaluate: this is our own source file's constant string-array literal, not
        # external or AI-supplied input.
        $highRiskScopes = Invoke-Expression $arrayLiteral

        $canonical = ($highRiskScopes | Sort-Object) -join '|'
        $hashBytes = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($canonical))
        $actualHash = -join ($hashBytes | ForEach-Object { $_.ToString('x2') })

        $expectedHash = 'e60972b920ed86de0f8c3b834b82a02d28a1f87ce4fd5754adcbc06a17025e88'

        if ($actualHash -ne $expectedHash) {
            Write-Host "Computed hash: $actualHash"
            Write-Host "Scopes considered: $canonical"
        }

        $actualHash | Should -Be $expectedHash
    }
}

