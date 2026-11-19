function Test-MPAIGOV1050 {
    <#
    .SYNOPSIS
    Checks that only SharePoint admins can change Restricted Content Discovery and Restricted Access Control on sites.
    .DESCRIPTION
    Reads the SharePoint tenant settings (Get-MtSpo, which uses Get-PnPTenant).

    Restricted Content Discovery keeps a site's content out of organization-wide search and Microsoft
    365 Copilot answers. Restricted Access Control limits a site to the groups you name. Both are
    controls you set while you fix oversharing before or during a Copilot rollout. When
    DelegateRestrictedContentDiscoverabilityManagement or DelegateRestrictedAccessControlManagement is
    True, site admins and owners can turn these controls off on their own sites. PnP.PowerShell returns
    them as DelegateRestrictedContentDiscoveryConfiguration and DelegateRestrictedAccessControlConfiguration;
    both names are read.

    Fails (Low) when either is True. Settings that aren't returned are listed and don't fail. Skips when
    neither is returned.
    .EXAMPLE
    Test-MPAIGOV1050
    .LINK
    https://learn.microsoft.com/sharepoint/restricted-content-discovery
    .LINK
    https://learn.microsoft.com/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant?view=sharepoint-ps
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1050',
        Title        = 'Only SharePoint admins should manage Restricted Content Discovery and Restricted Access Control',
        Product      = 'sharepoint',
        Feature      = 'access-control',
        Area         = 'ai',
        ResourceType = 'Tenant',
        Severity     = 'Low',
        Control      = 'nist-800-53-r5:AC-6',
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

    # PnP.PowerShell (Get-PnPTenant) and SharePoint Online PowerShell (Get-SPOTenant) name these differently.
    # Each row lists the PnP name first, then the SPO name.
    $Settings = @(
        @('DelegateRestrictedContentDiscoveryConfiguration', 'DelegateRestrictedContentDiscoverabilityManagement'),
        @('DelegateRestrictedAccessControlConfiguration', 'DelegateRestrictedAccessControlManagement') | ForEach-Object {
            $Names = $_
            $Found = $Names | ForEach-Object { $Tenant.PSObject.Properties[$_] } | Where-Object { $_ } | Select-Object -First 1
            $Names[0] | Select-Object @{ n = 'Setting'; e = { if ($Found) { $Found.Name } else { $Names[0] } } },
                @{ n = 'Returned'; e = { $null -ne $Found } },
                @{ n = 'Value'; e = { if ($Found) { $Found.Value } } }
        }
    )

    if (-not @($Settings | Where-Object Returned)) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
            "SharePoint didn't return the delegation settings. Your PnP.PowerShell version may not read them."
        )
        return $null
    }

    $Table = @(
        '| Setting | Value | Result |'
        '| --- | --- | --- |'
        $Settings | ForEach-Object {
            $Result = if (-not $_.Returned) { 'Not returned' } elseif ($_.Value -eq $true) { 'Fail' } else { 'Pass' }
            "| $($_.Setting) | $(if ($_.Returned) { $_.Value } else { '-' }) | $Result |"
        }
    ) -join "`n"

    $Delegated = @($Settings | Where-Object { $_.Returned -and $_.Value -eq $true })
    if ($Delegated.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. Site admins and owners can't turn off Restricted Content Discovery or Restricted Access Control.`n`n$Table"
        return $true
    }

    Add-MtTestResultDetail -Severity 'Low' -Result (
        "Site admins and owners can change $($Delegated.Count) restriction(s) that SharePoint admins set on their sites.`n`n$Table"
    )
    return $false
}
