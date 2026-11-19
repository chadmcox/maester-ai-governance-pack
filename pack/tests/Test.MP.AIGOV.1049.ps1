function Test-MPAIGOV1049 {
    <#
    .SYNOPSIS
    Checks that agents can't share SharePoint and OneDrive content with people outside the organization.
    .DESCRIPTION
    Reads the SharePoint tenant settings (Get-MtSpo, which uses Get-PnPTenant) and checks
    RestrictExternalSharingForAgents. When it's True, agentic identities can't share content with
    external users.

    Passes when RestrictExternalSharingForAgents is True, or when external sharing is off for the whole
    tenant (SharingCapability is Disabled), because then nothing can be shared outside. Fails (Medium)
    otherwise. Skips when the setting isn't returned: the setting is in preview, and older PnP.PowerShell
    versions don't read it.
    .EXAMPLE
    Test-MPAIGOV1049
    .LINK
    https://learn.microsoft.com/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant?view=sharepoint-ps
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1049',
        Title        = 'Agents should not be able to share SharePoint content with external users',
        Product      = 'sharepoint',
        Feature      = 'external-sharing',
        Area         = 'ai',
        ResourceType = 'Tenant',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:AC-21',
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

    $Sharing = [string]$Tenant.SharingCapability
    $Property = $Tenant.PSObject.Properties['RestrictExternalSharingForAgents']
    $Restricted = $Property -and $Property.Value -eq $true

    $Table = @(
        '| Setting | Value |'
        '| --- | --- |'
        "| RestrictExternalSharingForAgents | $(if ($Property) { $Property.Value } else { 'Not returned' }) |"
        "| SharingCapability | $(if ($Sharing) { $Sharing } else { 'Not returned' }) |"
    ) -join "`n"

    if ($Restricted) {
        Add-MtTestResultDetail -Result "Well done. Agents can't share SharePoint or OneDrive content with external users.`n`n$Table"
        return $true
    }
    if ($Sharing -eq 'Disabled') {
        Add-MtTestResultDetail -Result "Well done. External sharing is off for the whole tenant, so agents can't share content outside.`n`n$Table"
        return $true
    }
    if (-not $Property) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
            "SharePoint didn't return RestrictExternalSharingForAgents. The setting is in preview and may not be in your tenant yet, or your PnP.PowerShell version doesn't read it. External sharing is $Sharing."
        )
        return $null
    }

    Add-MtTestResultDetail -Severity 'Medium' -Result (
        "Agents can share SharePoint and OneDrive content with external users. External sharing is $Sharing for the tenant.`n`n$Table"
    )
    return $false
}
