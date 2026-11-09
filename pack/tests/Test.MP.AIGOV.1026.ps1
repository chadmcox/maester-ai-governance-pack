function Test-MPAIGOV1026 {
    <#
    .SYNOPSIS
    Finds enabled Copilot spending policies with no working budget alert.
    .DESCRIPTION
    For every enabled spendingPolicy, reads emailThresholdSettings and its recipients (beta Cost
    Management API) and applies the alert rules from chadmcox/Copilot "Billing Health Check":
      - Medium: no email alert (emailThresholdSettings missing or isEnabled false).
      - Medium: an alert recipient is disabled or no longer exists.
      - Low:    the alert has only one recipient.
    Without a working alert, nobody hears about a policy nearing its limit until users are blocked.
    .EXAMPLE
    Test-MPAIGOV1026
    .LINK
    https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/cost-management/overview
    .LINK
    https://learn.microsoft.com/copilot/implement/usage-based-billing-manage-copilot-credits#add-identity-based-spending-policy
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1026',
        Title        = 'Enabled spending policy should alert at least two active recipients',
        Product      = 'entra',
        Feature      = 'cost-management',
        Area         = 'ai',
        ResourceType = 'Tenant',
        Severity     = 'Medium',
        Permission   = 'Graph:Application:CopilotCostManagement-Policy.Read.All|Graph:Application:User.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading enabled Copilot spending policies.'
        $Policies = @(
            Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri 'copilot/costManagement/spendingPolicies' `
                -Select @('id', 'displayName', 'status')
        ) | Where-Object { [string]$_.status -eq 'enabled' }
    } catch {
        $ErrorRecord = $_
    }
    if ($ErrorRecord) {
        if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (Get-AIGovCostManagementSkipMessage)
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
        }
        return $null
    }

    $Policies = @($Policies)
    if ($Policies.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Well done. No enabled Copilot spending policies were found in the tenant.'
        return $true
    }

    $Findings = [System.Collections.Generic.List[pscustomobject]]::new()
    $Unread = [System.Collections.Generic.List[string]]::new()
    $UserCache = @{}

    foreach ($Policy in $Policies) {
        $Name = [string]$Policy.displayName
        $Base = "copilot/costManagement/spendingPolicies/$($Policy.id)/emailThresholdSettings"

        $Alert = $null
        try {
            $Alert = Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri $Base
        } catch {
            if (-not (Test-AIGovNotFoundError -ErrorRecord $_)) {
                Write-Verbose "Couldn't read alert settings for $($Policy.id): $($_.Exception.Message)"
                $Unread.Add($Name)
                continue
            }
        }

        if (-not $Alert -or -not [bool]$Alert.isEnabled) {
            $Findings.Add([pscustomobject]@{ Policy = $Name; Severity = 'Medium'; Target = '-'; Check = 'No email alert'; Fix = 'Turn on an alert at 80% with two owners as recipients.' })
            continue
        }

        try {
            $Recipients = @(Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri "$Base/recipients") |
                Where-Object { $_ -and -not [string]::IsNullOrWhiteSpace([string]$_.id) }
        } catch {
            Write-Verbose "Couldn't read alert recipients for $($Policy.id): $($_.Exception.Message)"
            $Unread.Add("$Name (recipients)")
            continue
        }
        $Recipients = @($Recipients)

        if ($Recipients.Count -lt 2) {
            $Findings.Add([pscustomobject]@{ Policy = $Name; Severity = 'Low'; Target = '-'; Check = "Only $($Recipients.Count) alert recipient(s)"; Fix = 'Add a second recipient.' })
        }

        foreach ($Recipient in $Recipients) {
            $Id = [string]$Recipient.id
            if (-not $UserCache.ContainsKey($Id)) {
                try {
                    $UserCache[$Id] = Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "users/$Id" -Select @('id', 'userPrincipalName', 'accountEnabled')
                } catch {
                    if (Test-AIGovNotFoundError -ErrorRecord $_) {
                        $UserCache[$Id] = 'NotFound'
                    } else {
                        Write-Verbose "Couldn't read recipient $Id`: $($_.Exception.Message)"
                        $UserCache[$Id] = 'Unread'
                    }
                }
            }
            $User = $UserCache[$Id]
            if ($User -is [string] -and $User -eq 'Unread') { $Unread.Add("$Name (recipient $Id)"); continue }
            if ($User -is [string] -and $User -eq 'NotFound') {
                $Findings.Add([pscustomobject]@{ Policy = $Name; Severity = 'Medium'; Target = $Id; Check = 'Alert recipient no longer exists'; Fix = 'Replace the recipient.' })
            } elseif (-not [bool]$User.accountEnabled) {
                $Findings.Add([pscustomobject]@{ Policy = $Name; Severity = 'Medium'; Target = [string]$User.userPrincipalName; Check = 'Alert recipient is disabled'; Fix = 'Replace the recipient.' })
            }
        }
    }

    $UnreadText = ''
    if ($Unread.Count -gt 0) {
        $UnreadText = " $($Unread.Count) item(s) couldn't be read and aren't reflected in this result: $(($Unread | ForEach-Object { ConvertTo-AIGovMarkdownCell -Text $_ }) -join ', ')."
    }

    if ($Unread.Count -gt 0 -and $Unread.Count -ge $Policies.Count -and $Findings.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Error -Result "Couldn't read alert settings for any enabled spending policy.$UnreadText"
        return $null
    }

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. All $($Policies.Count) enabled spending policy(ies) alert at least two active recipients.$UnreadText"
        return $true
    }

    $Rank = @{ High = 0; Medium = 1; Low = 2 }
    $Ordered = @($Findings | Sort-Object @{ Expression = { $Rank[$_.Severity] } }, Policy)
    $Result = "Found $($Findings.Count) alerting problem(s) on enabled spending policies.$UnreadText"
    $Result += "`n`n| Policy | Severity | Recipient | Check | Fix |"
    $Result += "`n| --- | --- | --- | --- | --- |"
    foreach ($Item in $Ordered) {
        $Result += "`n| $(ConvertTo-AIGovMarkdownCell -Text $Item.Policy) | $($Item.Severity) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Target) | " +
            "$(ConvertTo-AIGovMarkdownCell -Text $Item.Check) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Fix) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity $Ordered[0].Severity
    return $false
}
