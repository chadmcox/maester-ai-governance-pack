function Test-MPAIGOV1054 {
    <#
    .SYNOPSIS
    Checks that Microsoft Entra diagnostic settings export the agent risk logs.
    .DESCRIPTION
    Reads the log categories Microsoft Entra offers (GET /providers/microsoft.aadiam/
    diagnosticSettingsCategories) and the tenant's diagnostic settings (GET /providers/microsoft.aadiam/
    diagnosticSettings) from Azure Resource Manager.

    Microsoft Entra ID Protection writes agent risk to two log categories, RiskyAgents and
    AgentRiskEvents. They're kept only 30 days in Entra unless a diagnostic setting sends them to Log
    Analytics, a storage account, an event hub or a partner solution. CISA MS.AAD.4.1 (Maester core) checks
    the categories CISA names, and these two aren't among them.

    Fails (Medium) when a category in AIGOV.RequiredAgentLogCategories (default RiskyAgents and
    AgentRiskEvents) that the tenant offers isn't turned on in a diagnostic setting with a destination.
    Categories the tenant doesn't offer are listed and don't fail. Skips when neither can be read.
    .PARAMETER RequiredCategories
    Entra log categories that must be exported.
    .EXAMPLE
    Test-MPAIGOV1054
    .LINK
    https://learn.microsoft.com/entra/identity/monitoring-health/howto-configure-diagnostic-settings
    .LINK
    https://learn.microsoft.com/entra/id-protection/concept-risky-agents
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1054',
        Title        = 'Microsoft Entra diagnostic settings should export the agent risk logs',
        Product      = 'entra',
        Feature      = 'agent-identities',
        Area         = 'ai',
        ResourceType = 'Tenant',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:AU-6',
        Service      = 'Azure',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [MaesterParameter(Setting = 'AIGOV.RequiredAgentLogCategories')]
        [string[]]$RequiredCategories = @('RiskyAgents', 'AgentRiskEvents')
    )

    try {
        $Offered = Invoke-AIGovAzureList -RelativeUri '/providers/microsoft.aadiam/diagnosticSettingsCategories' -ApiVersion '2017-04-01-preview'
        $Settings = Invoke-AIGovAzureList -RelativeUri '/providers/microsoft.aadiam/diagnosticSettings' -ApiVersion '2017-04-01-preview'
    } catch {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Couldn't read the Microsoft Entra diagnostic settings." -SkippedError $_
        return $null
    }
    if ($null -eq $Offered -or $null -eq $Settings) {
        Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (
            "Couldn't read the Microsoft Entra diagnostic settings (401 or 403). Reading them needs an Entra role such as Security Reader or Global Reader."
        )
        return $null
    }

    $OfferedNames = @($Offered | Where-Object { $_.properties.categoryType -eq 'Logs' } | ForEach-Object { [string]$_.name })
    $Exported = @(
        foreach ($Setting in $Settings) {
            $P = $Setting.properties
            if (-not ($P.workspaceId -or $P.storageAccountId -or $P.eventHubAuthorizationRuleId -or $P.marketplacePartnerId)) { continue }
            foreach ($Log in @($P.logs | Where-Object { $_.enabled -eq $true })) {
                if ($Log.category) { [string]$Log.category }
                if ($Log.categoryGroup -eq 'allLogs') { $OfferedNames }
            }
        }
    )

    $Rows = @(
        $RequiredCategories | Select-Object @{ n = 'Category'; e = { $_ } },
            @{ n = 'Status'; e = {
                    if ($_ -notin $OfferedNames) { 'Not offered in this tenant' }
                    elseif ($_ -in $Exported) { 'Exported' }
                    else { 'Not exported' }
                }
            }
    )
    $Table = @('| Category | Status |', '| --- | --- |') + @($Rows | ForEach-Object { "| $($_.Category) | $($_.Status) |" }) -join "`n"
    $Missing = @($Rows | Where-Object Status -EQ 'Not exported')

    if ($Missing.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. The agent risk logs Microsoft Entra offers are exported by a diagnostic setting.`n`n$Table"
        return $true
    }

    Add-MtTestResultDetail -Severity 'Medium' -Result (
        "$($Missing.Count) agent log categor$(if ($Missing.Count -eq 1) { 'y is' } else { 'ies are' }) not exported by any Microsoft Entra diagnostic setting with a destination.`n`n$Table"
    )
    return $false
}
