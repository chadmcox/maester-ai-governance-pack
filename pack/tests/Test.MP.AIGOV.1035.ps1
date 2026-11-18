function Test-MPAIGOV1035 {
    <#
    .SYNOPSIS
    Finds agent identity blueprints that authenticate with a client secret.
    .DESCRIPTION
    Reads GET /applications/microsoft.graph.agentIdentityBlueprint with passwordCredentials and
    keyCredentials, then each flagged blueprint's federatedIdentityCredentials. A blueprint fails when
    it has at least one client secret that hasn't expired yet, whether or not it also has a
    certificate or federated credential.

    CISA's draft SCuBA agent baseline (MS.SI.2.1) says blueprints SHALL use federated identity
    credentials or certificates, not client secrets, and the joint CISA/NSA "Careful Adoption of
    Agentic AI Services" guidance says to replace static, long-lived secrets with short-lived
    credentials.

    This is broader than MT.1208, which flags a secret only when a federated credential is also
    present, or when it is expired, too long-lived or one of too many. Already-expired secrets are
    left to MT.1208 and not reported here.
    .EXAMPLE
    Test-MPAIGOV1035
    .LINK
    https://learn.microsoft.com/entra/agent-id/identity-platform/agent-blueprint
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1035',
        Title        = 'Agent identity blueprints should not authenticate with client secrets',
        Product      = 'entra',
        Feature      = 'agent-identities',
        Area         = 'ai',
        ResourceType = 'Application',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:IA-5',
        Permission   = 'Graph:Application:Application.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading agent identity blueprints and their credentials.'
        $Blueprints = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'applications/microsoft.graph.agentIdentityBlueprint' `
                -Select @('id', 'displayName', 'appId', 'passwordCredentials', 'keyCredentials')
        )
    } catch {
        if ($_.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (
                "Couldn't read agent identity blueprints (403). Confirm the Application.Read.All permission before re-running this check."
            )
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }

    $Now = [datetime]::UtcNow
    $WithSecrets = @(
        $Blueprints | Where-Object { $null -ne $_ } | Select-Object `
            @{ n = 'Id'; e = { [string]$_.id } },
            @{ n = 'Blueprint'; e = { [string]$_.displayName } },
            @{ n = 'AppId'; e = { [string]$_.appId } },
            @{ n = 'Secrets'; e = { @($_.passwordCredentials | Where-Object { $null -eq $_.endDateTime -or (ConvertTo-AIGovUtcDate $_.endDateTime) -gt $Now }).Count } },
            @{ n = 'Certificates'; e = { @($_.keyCredentials | Where-Object { $_ }).Count } } |
            Where-Object { $_.Secrets -gt 0 }
    )

    if ($WithSecrets.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. None of the $($Blueprints.Count) agent identity blueprint(s) has an active client secret."
        return $true
    }

    $Rows = @(
        $WithSecrets | Select-Object Blueprint, AppId, Secrets, Certificates, @{
            n = 'Federated credentials'; e = {
                try {
                    @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "applications/$($_.Id)/federatedIdentityCredentials" -Select @('id')).Count
                } catch {
                    Write-Verbose "Couldn't read federated credentials for $($_.Id): $($_.Exception.Message)"
                    'unknown'
                }
            }
        }
    )

    $Result = @(
        "Found $($Rows.Count) of $($Blueprints.Count) agent identity blueprint(s) with an active client secret. " +
        'Replace each secret with a federated identity credential (such as a managed identity) or a certificate, then remove the secret.'
        $Rows | ConvertTo-AIGovMarkdownTable -Property 'Blueprint', 'AppId', 'Secrets', 'Certificates', 'Federated credentials'
    ) -join "`n`n"

    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
