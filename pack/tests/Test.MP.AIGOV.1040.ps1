function Test-MPAIGOV1040 {
    <#
    .SYNOPSIS
    Checks the sensitivity label prerequisites that Copilot and agent data controls rely on.
    .DESCRIPTION
    Reads GET /security/dataSecurityAndGovernance/sensitivityLabels (v1.0), the tenant's labels with
    their sublabels, and checks enabled labels for:

    - At least one label scoped to sites or groups: applicableTo includes 'site' or 'unifiedGroup'.
      Without a container label you can't label SharePoint sites and Teams that agents and Copilot
      ground on. CISA draft SCuBA agent baseline MS.SI.6.1 and MS.SI.7.4. (Medium)
    - Unique names: two enabled labels with the same full name (parent/child) make DLP and
      Copilot exclusion rules ambiguous. CISA draft MS.SI.6.3. (Low)

    No labels at all fails Medium. Whether a default label is set is reported for information only:
    isDefault reflects a label policy, which this API may not resolve at tenant level.

    MT.1173 checks that labels are published (Security & Compliance PowerShell). This test reads
    Graph only and checks what Copilot-related controls need from the taxonomy.
    .EXAMPLE
    Test-MPAIGOV1040
    .LINK
    https://learn.microsoft.com/graph/api/tenantdatasecurityandgovernance-list-sensitivitylabels?view=graph-rest-1.0
    .LINK
    https://learn.microsoft.com/purview/sensitivity-labels-teams-groups-sites
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1040',
        Title        = 'Sensitivity labels should include a sites and groups label and use unique names',
        Product      = 'purview',
        Feature      = 'information-protection',
        Area         = 'data-protection',
        ResourceType = 'Tenant',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:AC-16',
        Permission   = 'Graph:Application:SensitivityLabel.Read',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading tenant sensitivity labels.'
        $Labels = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'security/dataSecurityAndGovernance/sensitivityLabels')
    } catch {
        if ($_.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (
                "Couldn't read sensitivity labels (403). Confirm the SensitivityLabel.Read permission before re-running this check."
            )
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }

    # Flatten parents and sublabels into one list with a full parent/child name.
    $Flat = @(
        foreach ($Label in @($Labels | Where-Object { $null -ne $_ })) {
            $ParentName = if ($Label.displayName) { [string]$Label.displayName } else { [string]$Label.name }
            $Label | Select-Object @{ n = 'FullName'; e = { $ParentName } }, isEnabled, applicableTo, isDefault
            foreach ($Sub in @($Label.sublabels | Where-Object { $null -ne $_ })) {
                $SubName = if ($Sub.displayName) { [string]$Sub.displayName } else { [string]$Sub.name }
                $Sub | Select-Object @{ n = 'FullName'; e = { "$ParentName/$SubName" } }, isEnabled, applicableTo, isDefault
            }
        }
    )
    $Enabled = @($Flat | Where-Object { $_.isEnabled -ne $false })

    if ($Enabled.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            'No enabled sensitivity labels were found. Copilot DLP rules, Restricted Content Discovery decisions and agent knowledge ' +
            'controls all depend on a label taxonomy. Create and publish one.'
        ) -Severity 'Medium'
        return $false
    }

    $Containers = @($Enabled | Where-Object { (@($_.applicableTo) -join ',') -match '(?i)\bsite\b|unifiedGroup' })
    $Duplicates = @(
        $Enabled | Group-Object -Property { ([string]$_.FullName).Trim().ToLowerInvariant() } |
            Where-Object { $_.Count -gt 1 } |
            Select-Object @{ n = 'Label'; e = { $_.Group[0].FullName } }, @{ n = 'Count'; e = { $_.Count } }
    )
    $DefaultNote = if (@($Enabled | Where-Object { $_.isDefault -eq $true }).Count -eq 0) {
        "`n`nFor information: no label reports isDefault. Confirm a default label is set in your label policies (CISA draft MS.SI.7.2)."
    } else { '' }

    if ($Containers.Count -gt 0 -and $Duplicates.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            "Well done. $($Containers.Count) of $($Enabled.Count) enabled label(s) apply to sites or groups, and every label name is unique.$DefaultNote"
        )
        return $true
    }

    $Parts = @(
        if ($Containers.Count -eq 0) {
            "None of the $($Enabled.Count) enabled label(s) applies to sites or groups. Turn on 'Groups & sites' scope for at least one label so " +
            'SharePoint sites and Teams that Copilot and agents ground on can be labeled.'
        }
        if ($Duplicates.Count -gt 0) {
            "$($Duplicates.Count) label name(s) are used more than once:"
            $Duplicates | ConvertTo-AIGovMarkdownTable -Property 'Label', 'Count'
        }
    )
    $Severity = if ($Containers.Count -eq 0) { 'Medium' } else { 'Low' }
    Add-MtTestResultDetail -Result (($Parts -join "`n`n") + $DefaultNote) -Severity $Severity
    return $false
}
