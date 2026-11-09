function Test-MPAIGOV1024 {
    <#
    .SYNOPSIS
    Finds classic Copilot Studio service principals with no owner, or that haven't signed in for a long time.
    .DESCRIPTION
    Older Copilot Studio agents run as ordinary service principals instead of Agent ID objects, so they have
    no enforced sponsor and no agent-aware lifecycle. MP.AIGOV.1005 lists them. This test applies the
    follow-up rules from chadmcox/Copilot "Agent and Tools Health Check":
      - Medium: no owner. Nobody is accountable for what the agent does.
      - Low:    enabled, created more than StaleDays ago, and no sign-in in StaleDays (or none recorded).
                Unused ones are the cheapest to retire instead of recreating with Agent ID.
    Sign-in activity comes from reports/servicePrincipalSignInActivities (beta, AuditLog.Read.All). If it
    can't be read, the sign-in check is skipped and the result says so.
    .PARAMETER StaleDays
    Days without a sign-in before an enabled service principal is reported. Defaults to 180, matching
    Maester's MT.1206; 90 is a stricter option.
    .EXAMPLE
    Test-MPAIGOV1024
    .LINK
    https://learn.microsoft.com/entra/agent-id/agent-service-principals
    .LINK
    https://learn.microsoft.com/graph/api/resources/serviceprincipalsigninactivity
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1024',
        Title        = 'Classic Copilot Studio service principal should have an owner and be in use',
        Product      = 'entra',
        Feature      = 'agents-without-agent-id',
        Area         = 'ai',
        ResourceType = 'ServicePrincipal',
        Severity     = 'Medium',
        Permission   = 'Graph:Application:Application.Read.All|Graph:Application:AuditLog.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [int] $StaleDays = 180
    )

    try {
        Write-Verbose 'Reading classic Copilot Studio service principals.'
        $Classic = @(Get-AIGovClassicCopilotServicePrincipal -Select @('id', 'appId', 'displayName', 'accountEnabled', 'createdDateTime'))
    } catch {
        $ErrorRecord = $_
    }
    if ($ErrorRecord) {
        if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
        }
        return $null
    }

    if ($Classic.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Well done. There are no classic Copilot Studio service principals in the tenant.'
        return $true
    }

    $Cutoff = [datetime]::UtcNow.AddDays(-$StaleDays)
    $Notes = [System.Collections.Generic.List[string]]::new()
    $Unread = [System.Collections.Generic.List[string]]::new()
    $SignInCheck = $true
    $Findings = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($Sp in $Classic) {
        $Name = if ([string]::IsNullOrWhiteSpace([string]$Sp.displayName)) { [string]$Sp.id } else { "$($Sp.displayName) ($($Sp.id))" }
        $Issues = [System.Collections.Generic.List[pscustomobject]]::new()

        try {
            $Owners = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "servicePrincipals/$($Sp.id)/owners" -Select @('id') | Where-Object { $_ })
            if ($Owners.Count -eq 0) { $Issues.Add([pscustomobject]@{ Severity = 'Medium'; Text = 'No owner' }) }
        } catch {
            Write-Verbose "Couldn't read owners of $($Sp.id): $($_.Exception.Message)"
            $Unread.Add($Name)
        }

        $Created = ConvertTo-AIGovUtcDate -Value $Sp.createdDateTime
        if ($SignInCheck -and [bool]$Sp.accountEnabled -and $Created -and $Created -lt $Cutoff -and -not [string]::IsNullOrWhiteSpace([string]$Sp.appId)) {
            try {
                $Activity = @(Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri 'reports/servicePrincipalSignInActivities' -Filter "appId eq '$($Sp.appId)'") |
                    Where-Object { $_ } | Select-Object -First 1
                $Last = if ($Activity) { ConvertTo-AIGovUtcDate -Value $Activity.lastSignInActivity.lastSignInDateTime } else { $null }
                if (-not $Last) {
                    $Issues.Add([pscustomobject]@{ Severity = 'Low'; Text = "No sign-in recorded, created $($Created.ToString('yyyy-MM-dd'))" })
                } elseif ($Last -lt $Cutoff) {
                    $Issues.Add([pscustomobject]@{ Severity = 'Low'; Text = "No sign-in for $StaleDays days (last $($Last.ToString('yyyy-MM-dd')))" })
                }
            } catch {
                Write-Verbose "Couldn't read sign-in activity: $($_.Exception.Message)"
                $SignInCheck = $false
                $Notes.Add("The sign-in check was skipped: reports/servicePrincipalSignInActivities couldn't be read (needs AuditLog.Read.All).")
            }
        }

        if ($Issues.Count -gt 0) {
            $Findings.Add([pscustomobject]@{
                Name     = $Name
                Severity = if ($Issues | Where-Object Severity -EQ 'Medium') { 'Medium' } else { 'Low' }
                Issues   = ($Issues.Text -join '; ')
            })
        }
    }

    if ($Unread.Count -gt 0) {
        $Notes.Add("$($Unread.Count) service principal(s) couldn't be read and aren't reflected in this result: $(($Unread | ForEach-Object { ConvertTo-AIGovMarkdownCell -Text $_ }) -join ', ').")
    }
    $NoteText = if ($Notes.Count -gt 0) { "`n`n" + (($Notes | ForEach-Object { "- $_" }) -join "`n") } else { '' }

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. All $($Classic.Count) classic Copilot Studio service principal(s) have an owner and have been used in the last $StaleDays days.$NoteText"
        return $true
    }

    $Ordered = @($Findings | Sort-Object @{ Expression = { if ($_.Severity -eq 'Medium') { 0 } else { 1 } } }, Name)
    $Result = "Found $($Findings.Count) of $($Classic.Count) classic Copilot Studio service principal(s) with no owner or no recent use. " +
        "There's no in-place migration to Agent ID: retire unused ones, and give the rest an owner.$NoteText"
    $Result += "`n`n| Service principal | Severity | Issues |"
    $Result += "`n| --- | --- | --- |"
    foreach ($Item in $Ordered) {
        $Result += "`n| $(ConvertTo-AIGovMarkdownCell -Text $Item.Name) | $($Item.Severity) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Issues) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity $Ordered[0].Severity
    return $false
}
