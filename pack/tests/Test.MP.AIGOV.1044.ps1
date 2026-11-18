function Test-MPAIGOV1044 {
    <#
    .SYNOPSIS
    Checks that Copilot and AI interaction audit records are kept at least as long as you require.
    .DESCRIPTION
    Reads audit log retention policies with Get-UnifiedAuditLogRetentionPolicy (Security & Compliance
    PowerShell). A policy covers Copilot interactions when its RecordTypes include CopilotInteraction
    (Microsoft 365 Copilot, Copilot Chat, Cowork, Security Copilot and Copilot Studio agents) and it
    isn't narrowed by Operations or UserIds. The test fails when no such policy exists, or the longest
    one keeps records for less than MinimumRetention (default TwelveMonths).

    Without a policy, CopilotInteraction records follow the Audit (Standard) default of 180 days.
    Audit retention policies need Microsoft Purview Audit (Premium); ten-year retention also needs
    the add-on license.

    Coverage of ConnectedAIAppInteraction (custom and third-party AI apps registered in your tenant)
    is reported for information.

    CISA's draft SCuBA agent baseline says agent conversations and actions SHALL be logged and
    retained (MS.SI.5.1) and audit retention for AI interactions SHALL meet records requirements
    (MS.SI.11.4). MT.1172 checks that the unified audit log is on.
    .EXAMPLE
    Test-MPAIGOV1044
    .EXAMPLE
    Test-MPAIGOV1044 -MinimumRetention TenYears
    .LINK
    https://learn.microsoft.com/purview/audit-copilot
    .LINK
    https://learn.microsoft.com/purview/audit-log-retention-policies
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1044',
        Title        = 'Copilot interaction audit records should be retained for at least your required period',
        Product      = 'purview',
        Feature      = 'audit',
        Area         = 'logging-and-detection',
        ResourceType = 'Policy',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:AU-11',
        Service      = 'SecurityCompliance',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The shortest acceptable retention for CopilotInteraction audit records.
        [MaesterParameter(Setting = 'AIGOV.MinimumAiAuditRetention')]
        [ValidateSet('SixMonths', 'NineMonths', 'TwelveMonths', 'TenYears')]
        [string]$MinimumRetention = 'TwelveMonths'
    )

    $Months = @{ ThreeMonths = 3; SixMonths = 6; NineMonths = 9; TwelveMonths = 12; FiveYears = 60; SevenYears = 84; TenYears = 120 }

    try {
        Write-Verbose 'Reading audit log retention policies.'
        $Policies = @(Get-UnifiedAuditLogRetentionPolicy -ErrorAction Stop)
    } catch {
        $Message = [string]$_.Exception.Message
        if ($_.Exception -is [System.Management.Automation.CommandNotFoundException] -or $Message -match 'is not recognized') {
            Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        } elseif ($Message -match '(?i)403|forbidden|access denied|not authorized|license') {
            Add-MtTestResultDetail -SkippedBecause NotLicensedAdvAudit
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }

    $Rows = @(
        $Policies | Where-Object { $null -ne $_ -and $_.Enabled -ne $false -and @($_.Operations | Where-Object { $_ }).Count -eq 0 -and @($_.UserIds | Where-Object { $_ }).Count -eq 0 } |
            Select-Object @{ n = 'Policy'; e = { [string]$_.Name } },
                @{ n = 'RecordTypes'; e = { @($_.RecordTypes | ForEach-Object { [string]$_ }) } },
                @{ n = 'Duration'; e = { [string]$_.RetentionDuration } },
                @{ n = 'Months'; e = { [int]$Months[[string]$_.RetentionDuration] } }
    )

    $Copilot = @($Rows | Where-Object { $_.RecordTypes -contains 'CopilotInteraction' } | Sort-Object Months -Descending)
    $Connected = @($Rows | Where-Object { $_.RecordTypes -contains 'ConnectedAIAppInteraction' } | Sort-Object Months -Descending)
    $ConnectedNote = if ($Connected.Count -gt 0) {
        "`n`nFor information: ConnectedAIAppInteraction records are kept for $($Connected[0].Duration) by '$($Connected[0].Policy)'."
    } else {
        "`n`nFor information: no audit retention policy covers ConnectedAIAppInteraction (custom and third-party AI apps registered in your tenant)."
    }

    if ($Copilot.Count -gt 0 -and $Copilot[0].Months -ge $Months[$MinimumRetention]) {
        Add-MtTestResultDetail -Result (
            "Well done. '$($Copilot[0].Policy)' keeps CopilotInteraction audit records for $($Copilot[0].Duration) (minimum $MinimumRetention).$ConnectedNote"
        )
        return $true
    }

    $Detail = if ($Copilot.Count -eq 0) {
        'No audit retention policy covers the CopilotInteraction record type, so Copilot and agent interaction records follow the Audit (Standard) default of 180 days.'
    } else {
        "The longest policy covering CopilotInteraction, '$($Copilot[0].Policy)', keeps records for $($Copilot[0].Duration), less than the required $MinimumRetention."
    }
    Add-MtTestResultDetail -Result (
        "$Detail Create an audit retention policy for CopilotInteraction with a duration of at least $MinimumRetention.$ConnectedNote"
    ) -Severity 'Medium'
    return $false
}
