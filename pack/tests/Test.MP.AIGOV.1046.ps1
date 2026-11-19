function Test-MPAIGOV1046 {
    <#
    .SYNOPSIS
    Finds Azure OpenAI and AI Services model deployments without a content filter that blocks prompt attacks.
    .DESCRIPTION
    Reads the accounts from Azure Resource Graph, then each account's model deployments
    (GET {account}/deployments) and content filters (GET {account}/raiPolicies) from Azure Resource
    Manager (a content filter is called a guardrail in the new Foundry portal). A text model deployment
    fails when:

    - It has no content filter (raiPolicyName is empty).
    - Its content filter doesn't turn on and block Prompt Shields for user prompts (the jailbreak
      filter). Annotate-only doesn't count: the prompt still reaches the model.
    - With -RequireIndirectAttackFilter (setting AIGOV.RequireIndirectAttackFilter), its content filter
      doesn't turn on and block Prompt Shields for indirect attacks (instructions hidden in documents,
      email or web content the model reads).

    Embedding, speech and image models are left out: Prompt Shields screen text prompts to generative
    models. A deployment on Microsoft.DefaultV2 that the account doesn't return in its filter list is
    counted as passing, because Microsoft documents Prompt Shields for user prompts as on by default.
    Deployments whose filter can't be read are listed for information. No deployments is a pass.
    .PARAMETER RequireIndirectAttackFilter
    Also require Prompt Shields for indirect attacks. Off by default, as it is in Azure, because it only
    works when the app marks documents in the prompt.
    .EXAMPLE
    Test-MPAIGOV1046
    .LINK
    https://learn.microsoft.com/azure/ai-foundry/openai/how-to/content-filters
    .LINK
    https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection
    .LINK
    https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-artificial-intelligence-security
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1046',
        Title        = 'Azure AI model deployments should use a content filter that blocks prompt attacks',
        Product      = 'azure',
        Feature      = 'content-safety',
        Area         = 'ai',
        ResourceType = 'AzureResource',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:SI-10',
        Service      = 'Azure',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [MaesterParameter(Setting = 'AIGOV.RequireIndirectAttackFilter')]
        [bool]$RequireIndirectAttackFilter = $false
    )

    # Model families Prompt Shields don't apply to: embeddings, speech and image generation.
    $NonTextModel = '(?i)embed|whisper|tts|transcribe|dall-e|gpt-image|sora'
    # Content filter names for Prompt Shields: "Jailbreak" / "Indirect Attack" in content filters,
    # "User prompt attack" / "Document attack" in Foundry guardrails. Matched loosely; verify live.
    $UserPromptShield = '(?i)jailbreak|user.?prompt.?attack|prompt.?shield'
    $IndirectShield = '(?i)indirect|document.?attack'

    try {
        $Accounts = @(Get-AIGovAzureAiAccount)
    } catch {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Couldn't query Azure Resource Graph for AI accounts." -SkippedError $_
        return $null
    }
    if ($Accounts.Count -eq 0) {
        Add-MtTestResultDetail -Result 'No Azure OpenAI or Azure AI Services accounts were found in the subscriptions Maester can read.'
        return $true
    }

    $Rows = @($Accounts | Get-AIGovAzureAiDeployment)

    # One content filter list per account that has text model deployments. $null means it couldn't be read.
    $PoliciesByAccount = @{}
    foreach ($AccountId in @($Rows | Where-Object { -not $_.ReadError -and $_.Model -notmatch $NonTextModel } | Select-Object -ExpandProperty AccountId -Unique)) {
        $PoliciesByAccount[$AccountId] = try {
            $Policies = Invoke-AIGovAzureList -RelativeUri "$AccountId/raiPolicies" -ApiVersion '2024-10-01'
            if ($null -ne $Policies) {
                $ByName = @{}
                foreach ($Policy in $Policies) { $ByName[[string]$Policy.name] = $Policy.properties }
                $ByName
            }
        } catch {
            Write-Verbose "Couldn't read the content filters of $AccountId`: $($_.Exception.Message)"
            $null
        }
    }

    $TextRows = @($Rows | Where-Object { -not $_.ReadError -and $_.Model -notmatch $NonTextModel })
    $Checked = @(
        foreach ($Row in $TextRows) {
            $PolicyName = [string]$Row.RaiPolicy
            $Policies = $PoliciesByAccount[[string]$Row.AccountId]
            $Policy = if ($Policies -and $PolicyName) { $Policies[$PolicyName] }
            $Filters = @($Policy.contentFilters | Where-Object { $null -ne $_ })
            $Blocks = { param($Pattern) [bool]@($Filters | Where-Object { [string]$_.name -match $Pattern -and $_.enabled -eq $true -and ($_.blocking -eq $true -or [string]$_.action -eq 'BLOCKING') }) }

            $Status = if (-not $PolicyName) { 'Fail' }
                elseif ($null -eq $Policies) { 'Unread' }
                elseif ($null -eq $Policy) { if ($PolicyName -eq 'Microsoft.DefaultV2') { 'Pass' } else { 'Unread' } }
                else { 'Check' }

            $Reasons = @(
                if (-not $PolicyName) { 'no content filter' }
                if ($Status -eq 'Check' -and -not (& $Blocks $UserPromptShield)) { 'Prompt Shields for user prompts off or annotate-only' }
                if ($Status -eq 'Check' -and $RequireIndirectAttackFilter -and -not (& $Blocks $IndirectShield)) { 'Prompt Shields for indirect attacks off or annotate-only' }
            )
            $Row | Select-Object Account, Subscription, 'Resource group', Deployment,
                @{ n = 'Model'; e = { (@($_.Model, $_.Version) | Where-Object { $_ }) -join ' ' } },
                @{ n = 'Content filter'; e = { if ($PolicyName) { $PolicyName } else { '(none)' } } },
                @{ n = 'Mode'; e = { [string]$Policy.mode } },
                @{ n = 'Status'; e = { if ($Reasons.Count -gt 0) { 'Fail' } elseif ($Status -eq 'Unread') { 'Unread' } else { 'Pass' } } },
                @{ n = 'Reason'; e = { $Reasons -join '; ' } }
        }
    )

    $Findings = @($Checked | Where-Object Status -EQ 'Fail')
    $Unread = @($Checked | Where-Object Status -EQ 'Unread')
    $UnreadAccounts = @($Rows | Where-Object ReadError)
    $Skipped = @($Rows | Where-Object { -not $_.ReadError -and $_.Model -match $NonTextModel }).Count

    if ($TextRows.Count -eq 0 -and $UnreadAccounts.Count -gt 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Couldn't read the model deployments of $($UnreadAccounts.Count) AI account(s). Maester needs Reader on those subscriptions."
        return $null
    }
    if ($Checked.Count -gt 0 -and $Unread.Count -eq $Checked.Count) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Couldn't read the content filters of any of the $($Checked.Count) text model deployment(s)."
        return $null
    }

    $Notes = @(
        if ($Skipped -gt 0) { "$Skipped embedding, speech or image deployment(s) were left out." }
        if ($UnreadAccounts.Count -gt 0) { "Couldn't read the deployments of $($UnreadAccounts.Count) account(s): $(@($UnreadAccounts.Account) -join ', ')." }
        if ($Unread.Count -gt 0) { "Couldn't read the content filter of $($Unread.Count) deployment(s): $(@($Unread | ForEach-Object { "$($_.Account)/$($_.Deployment)" }) -join ', ')." }
    )

    if ($Findings.Count -eq 0) {
        $Pass = if ($Checked.Count -eq 0) {
            "No text model deployments were found in $($Accounts.Count) AI account(s)."
        } else {
            "Well done. All $($Checked.Count - $Unread.Count) text model deployment(s) checked use a content filter that blocks prompt attacks."
        }
        Add-MtTestResultDetail -Result (@($Pass) + $Notes -join "`n`n")
        return $true
    }

    $Result = @(
        "Found $($Findings.Count) of $($Checked.Count) text model deployment(s) without a content filter that blocks prompt attacks."
        $Findings | Sort-Object Subscription, Account, Deployment | ConvertTo-AIGovMarkdownTable -Property 'Account', 'Deployment', 'Model', 'Content filter', 'Mode', 'Reason'
        $Notes
    ) -join "`n`n"
    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
