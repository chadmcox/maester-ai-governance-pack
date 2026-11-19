function Test-MPAIGOV1051 {
    <#
    .SYNOPSIS
    Checks that people see a warning before they share a SharePoint site or its content with an agent.
    .DESCRIPTION
    Reads the SharePoint tenant settings (Get-MtSpo, which uses Get-PnPTenant) and checks
    EnableAgentWorkerSharingDisclaimer. When it's True, users see a disclaimer when they share a site or
    its content with an agent worker or AI teammate, so they think about what the agent will be able to
    read and act on.

    Passes when EnableAgentWorkerSharingDisclaimer is True. Fails (Low) when it's False. Skips when the
    setting isn't returned: Microsoft lists it as preview, and older PnP.PowerShell versions don't read it.
    .EXAMPLE
    Test-MPAIGOV1051
    .LINK
    https://learn.microsoft.com/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant?view=sharepoint-ps
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1051',
        Title        = 'Users should see a disclaimer before they share SharePoint content with an agent',
        Product      = 'sharepoint',
        Feature      = 'sharing-links',
        Area         = 'ai',
        ResourceType = 'Tenant',
        Severity     = 'Low',
        Control      = 'nist-800-53-r5:AT-2',
        Service      = 'SharePointOnline',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $Tenant = Get-MtSpo
    } catch {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Couldn't read the SharePoint tenant settings." -SkippedError $_
        return $null
    }

    $Property = $Tenant.PSObject.Properties['EnableAgentWorkerSharingDisclaimer']
    if (-not $Property) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
            "SharePoint didn't return EnableAgentWorkerSharingDisclaimer. The setting is in preview and may not be in your tenant yet, or your PnP.PowerShell version doesn't read it."
        )
        return $null
    }

    $Table = "| Setting | Value |`n| --- | --- |`n| EnableAgentWorkerSharingDisclaimer | $($Property.Value) |"
    if ($Property.Value -eq $true) {
        Add-MtTestResultDetail -Result "Well done. Users see a disclaimer before they share a site or its content with an agent.`n`n$Table"
        return $true
    }

    Add-MtTestResultDetail -Severity 'Low' -Result "Users can share sites and content with agents without seeing a disclaimer.`n`n$Table"
    return $false
}
