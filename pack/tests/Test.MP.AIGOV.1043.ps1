function Test-MPAIGOV1043 {
    <#
    .SYNOPSIS
    Checks which Copilot protections your enforced Copilot DLP policies actually turn on.
    .DESCRIPTION
    Reads DLP policies and rules from Security & Compliance PowerShell (Get-MtExo -Request
    DlpCompliancePolicy and DlpComplianceRule). A policy targets Copilot when its Locations include
    the Microsoft 365 Copilot location (470f2276-e011-4e9d-a6ec-20768be3a4b0), its EnforcementPlanes
    include CopilotExperiences, or its legacy Copilot location or workload fields name Copilot, the
    same detection MT.1175 uses. Only policies that are enabled, in Mode 'Enable' and not in
    simulation count, and only their rules that aren't disabled.

    Each enforced rule is classified against the four protections the Copilot location supports:

    - Block prompts with sensitive info types: a sensitive information type condition with
      RestrictAccess UploadText or ExcludeContentProcessing = Block. (Medium if missing)
    - Block labeled files and email: a sensitivity label condition with ExcludeContentProcessing = Block. (Medium if
      missing; needs Microsoft 365 E5-level Purview)
    - Block web search for sensitive prompts: RestrictWebGrounding = true. (Low if missing)
    - Exclude external email from grounding: FromScope NotInOrganization with the processing block.
      (Low if missing; preview)

    MT.1175 and CIS M365 3.2.3 check that an enforced Copilot DLP policy exists; this test checks what
    it protects. When no enforced Copilot DLP policy exists the test skips and leaves that finding to
    MT.1175. Maps to CISA draft SCuBA agent baseline MS.SI.10.2, 10.3, 10.5 and 10.6.
    .EXAMPLE
    Test-MPAIGOV1043
    .LINK
    https://learn.microsoft.com/purview/dlp-microsoft365-copilot-location-learn-about
    .LINK
    https://learn.microsoft.com/powershell/module/exchangepowershell/new-dlpcompliancerule
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1043',
        Title        = 'Copilot DLP policies should block sensitive prompts, labeled content, and web search for sensitive prompts',
        Product      = 'purview',
        Feature      = 'data-loss-prevention',
        Area         = 'data-protection',
        ResourceType = 'Policy',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:AC-4',
        Service      = ('ExchangeOnline', 'SecurityCompliance'),
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading DLP policies and rules.'
        $Policies = @(Get-MtExo -Request DlpCompliancePolicy)
        $Rules = @(Get-MtExo -Request DlpComplianceRule)
    } catch {
        if ($_.Exception.Message -match '(?i)403|forbidden|access denied|not authorized') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }

    $CopilotLocationId = '470f2276-e011-4e9d-a6ec-20768be3a4b0'
    $Enforced = @(
        $Policies | Where-Object {
            $LocationText = (@($_.Locations) | ConvertTo-Json -Depth 10 -Compress) + " $($_.EnforcementPlanes) $($_.Workload) $($_.MicrosoftCopilotLocation)"
            $IsCopilot = $LocationText -match "(?i)$CopilotLocationId|Copilot"
            $IsEnforced = $_.Enabled -ne $false -and -not $_.IsSimulationPolicy -and ([string]::IsNullOrEmpty([string]$_.Mode) -or [string]$_.Mode -eq 'Enable')
            $IsCopilot -and $IsEnforced
        }
    )

    if ($Enforced.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
            'No enforced DLP policy targets the Microsoft 365 Copilot location. MT.1175 reports that finding; create one, then re-run this check.'
        )
        return $null
    }

    $PolicyNames = @($Enforced | ForEach-Object { [string]$_.Name })
    $ActiveRules = @($Rules | Where-Object { [string]$_.ParentPolicyName -in $PolicyNames -and $_.Disabled -ne $true })

    # Rules made in PowerShell name the Copilot activity in RestrictAccess (setting = UploadText or
    # ExcludeContentProcessing). Rules made in the Purview portal can leave setting empty and put the
    # activity in AdvancedRule as HasActivity = UploadText (seen live, Nov 18 2026).
    $Classified = @(
        $ActiveRules | Select-Object @{ n = 'Rule'; e = { [string]$_.Name } }, @{ n = 'Policy'; e = { [string]$_.ParentPolicyName } },
            @{ n = 'Conditions'; e = { (@($_.ContentContainsSensitiveInformation) | ConvertTo-Json -Depth 20 -Compress) + " $($_.AdvancedRule)" } },
            @{ n = 'PromptActivity'; e = { "$($_.HasActivity) $($_.AdvancedRule)" -match '(?i)UploadText' } },
            @{ n = 'Block'; e = { @($_.RestrictAccess | Where-Object { [string]$_.value -eq 'Block' } | ForEach-Object { [string]$_.setting }) } },
            @{ n = 'WebSearch'; e = { $_.RestrictWebGrounding -eq $true } },
            @{ n = 'External'; e = { [string]$_.FromScope -match '(?i)NotInOrganization' } } |
            Select-Object Rule, Policy, Conditions, WebSearch, External,
                @{ n = 'Blocks'; e = { $_.Block -contains 'ExcludeContentProcessing' -or (@($_.Block | Where-Object { -not $_ }).Count -gt 0 -and -not $_.PromptActivity) } },
                @{ n = 'BlocksPrompts'; e = { @($_.Block | Where-Object { $_ -in 'UploadText', 'ExcludeContentProcessing' }).Count -gt 0 -or (@($_.Block | Where-Object { -not $_ }).Count -gt 0 -and $_.PromptActivity) } } |
            Select-Object Rule, Policy, WebSearch, External, Blocks, BlocksPrompts,
                @{ n = 'HasLabels'; e = { $_.Conditions -match '(?i)"type"\s*:\s*"Sensitivity"|"labels"\s*:\s*\[\s*\{' } },
                @{ n = 'HasSits'; e = { $_.Conditions -match '(?i)"sensitivetypes"\s*:\s*\[\s*\{' -or ($_.Conditions -match '(?i)"name"\s*:' -and $_.Conditions -notmatch '(?i)"labels"\s*:\s*\[\s*\{') } }
    )

    # One row per protection the Copilot location supports: name, weight if missing, and the rule test.
    $Checks = @(
        , @('Block prompts with sensitive info types', 'Medium', { $_.BlocksPrompts -and $_.HasSits -and -not $_.External })
        , @('Block labeled files and email', 'Medium', { $_.Blocks -and $_.HasLabels })
        , @('Block web search for sensitive prompts', 'Low', { $_.WebSearch })
        , @('Exclude external email from grounding', 'Low', { $_.External -and $_.Blocks })
    )
    $Protections = @(
        $Checks | ForEach-Object {
            $Check = $_
            $Check[0] | Select-Object @{ n = 'Protection'; e = { $_ } }, @{ n = 'Weight'; e = { $Check[1] } },
                @{ n = 'Covered'; e = { @($Classified | Where-Object $Check[2]).Count -gt 0 } }
        }
    )

    $Table = $Protections | Select-Object Protection, @{ n = 'Status'; e = { if ($_.Covered) { 'On' } else { 'Missing' } } } |
        ConvertTo-AIGovMarkdownTable -Property 'Protection', 'Status'
    $Missing = @($Protections | Where-Object { -not $_.Covered })

    if ($Missing.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. $($Enforced.Count) enforced Copilot DLP polic(ies) turn on all four Copilot protections.`n`n$Table"
        return $true
    }

    $Severity = if (@($Missing | Where-Object { $_.Weight -eq 'Medium' }).Count -gt 0) { 'Medium' } else { 'Low' }
    Add-MtTestResultDetail -Severity $Severity -Result (
        "$($Enforced.Count) enforced Copilot DLP polic(ies) with $($ActiveRules.Count) active rule(s) leave $($Missing.Count) of 4 Copilot protections off." +
        "`n`n$Table`n`nRule conditions are matched from the rule's text; confirm a 'Missing' row in the Purview portal before changing a policy."
    )
    return $false
}
