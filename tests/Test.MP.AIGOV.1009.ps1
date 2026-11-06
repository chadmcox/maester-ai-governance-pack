function Test-MPAIGOV1009 {
    <#
    .SYNOPSIS
    Finds Agent Identity Blueprint client secrets and certificates nearing expiration.
    .DESCRIPTION
    Maester's own MT.1208 (Test-MtEntraAgentBlueprintCredentialHygiene) flags blueprint client
    secrets that are already expired, valid for more than 730 days, exceed a maximum active-secret
    count, or are retained alongside a federated identity credential -- confirmed by reading its
    full source. It has no forward-looking condition: nothing warns before a still-active
    credential expires. This test fills that gap, flagging any active (not yet expired) client
    secret or certificate credential whose endDateTime falls within a configurable warning window
    (default 30 days) of now. An already-expired credential is MT.1208's job, not this test's --
    this test explicitly excludes endDateTime values in the past.
    .EXAMPLE
    Test-MPAIGOV1009
    .LINK
    https://learn.microsoft.com/graph/api/agentidentityblueprint-list?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1009',
        Title        = 'Agent Identity Blueprint credential should not be nearing expiration',
        Product      = 'entra',
        Feature      = 'agent-identities',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'Low',
        Control      = 'nist-800-53-r5:IA-5',
        Permission   = 'Graph:Application:Application.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview',
        LongRunning
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Number of days before expiration at which a still-active credential is flagged. Defaults to 30.
        [Parameter(Mandatory = $false)]
        [int]$WarningDays = 30
    )

    try {
        Write-Verbose 'Reading Agent Identity Blueprints with credential metadata.'
        $Blueprints = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' `
                -RelativeUri 'applications/microsoft.graph.agentIdentityBlueprint' `
                -Select @('id', 'displayName', 'appId', 'passwordCredentials', 'keyCredentials')
        )
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

    if ($Blueprints.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Well done. No Agent Identity Blueprints were found in the tenant.'
        return $true
    }

    $UtcNow = (Get-Date).ToUniversalTime()
    $WarningThreshold = $UtcNow.AddDays($WarningDays)

    $NearingExpiration = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($Blueprint in $Blueprints) {
        $CredentialSets = @(
            @{ Type = 'Secret'; Credentials = @($Blueprint.passwordCredentials) }
            @{ Type = 'Certificate'; Credentials = @($Blueprint.keyCredentials) }
        )
        foreach ($CredentialSet in $CredentialSets) {
            foreach ($Credential in $CredentialSet.Credentials) {
                # Graph-typed date/time properties arrive as native [datetime] objects; cast directly
                # rather than round-tripping through [string], which can silently misparse.
                $EndDateTime = $Credential.endDateTime -as [datetime]
                if ($null -eq $EndDateTime) { continue }
                $EndDateTime = $EndDateTime.ToUniversalTime()

                # Already expired is MT.1208's finding, not this one's.
                if ($EndDateTime -lt $UtcNow) { continue }

                if ($EndDateTime -le $WarningThreshold) {
                    $DaysRemaining = [int][math]::Ceiling(($EndDateTime - $UtcNow).TotalDays)
                    $NearingExpiration.Add([pscustomobject]@{
                        BlueprintId   = [string]$Blueprint.id
                        DisplayName   = [string]$Blueprint.displayName
                        AppId         = [string]$Blueprint.appId
                        Type          = $CredentialSet.Type
                        KeyId         = [string]$Credential.keyId
                        DaysRemaining = $DaysRemaining
                        EndDateTime   = $EndDateTime.ToString('yyyy-MM-dd')
                    })
                }
            }
        }
    }

    if ($NearingExpiration.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            "Well done. No Agent Identity Blueprint client secret or certificate is nearing expiration (within $WarningDays days)."
        )
        return $true
    }

    $Result = "Found $($NearingExpiration.Count) Agent Identity Blueprint credential(s) nearing expiration (within $WarningDays days)."
    $Result += "`n`n| Blueprint object ID | Display name | App ID | Type | Key ID | Days remaining | Expires |"
    $Result += "`n| --- | --- | --- | --- | --- | --- | --- |"
    foreach ($Item in $NearingExpiration) {
        $Name = [string]$Item.DisplayName
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
        $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
        $Name = $Name -replace "`r?`n", ' '
        $Result += "`n| $($Item.BlueprintId) | $Name | $($Item.AppId) | $($Item.Type) | $($Item.KeyId) | " +
            "$($Item.DaysRemaining) | $($Item.EndDateTime) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'Low'
    return $false
}
