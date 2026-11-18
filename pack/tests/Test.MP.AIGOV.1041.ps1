function Test-MPAIGOV1041 {
    <#
    .SYNOPSIS
    Finds agent identity blueprints from other organizations whose publisher isn't verified.
    .DESCRIPTION
    Reads GET /organization for the tenant ID and GET
    /servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal with appOwnerOrganizationId and
    verifiedPublisher. A blueprint principal is foreign when appOwnerOrganizationId is set and isn't
    this tenant or a Microsoft tenant. A foreign blueprint principal fails when
    verifiedPublisher.verifiedPublisherId is empty: agents built from it act in your tenant on behalf
    of a publisher Microsoft hasn't verified.

    CISA/NSA "Careful Adoption of Agentic AI Services" says to keep a trusted registry of third-party
    components and verify their origin before integrating them.

    MT.1207 checks whether foreign blueprint principals hold privileged directory roles; this test
    checks who published them.
    .EXAMPLE
    Test-MPAIGOV1041
    .LINK
    https://learn.microsoft.com/entra/identity-platform/publisher-verification-overview
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1041',
        Title        = 'Agent identity blueprints from other organizations should come from a verified publisher',
        Product      = 'entra',
        Feature      = 'agent-identities',
        Area         = 'ai',
        ResourceType = 'ServicePrincipal',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:SR-3',
        Permission   = 'Graph:Application:Application.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Microsoft's first-party app-owning tenants.
    $MicrosoftTenants = @('f8cdef31-a31e-4b4a-93e4-5f571e91255a', '72f988bf-86f1-41af-91ab-2d7cd011db47')

    try {
        Write-Verbose 'Reading the tenant ID and agent identity blueprint principals.'
        $TenantId = [string](@(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'organization' -Select @('id'))[0].id)
        $Principals = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal' `
                -Select @('id', 'displayName', 'appId', 'appOwnerOrganizationId', 'verifiedPublisher')
        )
    } catch {
        $Message = "$($_.Exception.Message) $($_.ErrorDetails.Message)"
        if ($Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (
                "Couldn't read blueprint principals (403). Confirm the Application.Read.All permission before re-running this check."
            )
        } elseif ($Message -match '(?i)verifiedPublisher' -and $Message -match '(?i)400|badrequest|property') {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
                'The agentIdentityBlueprintPrincipal API does not support selecting verifiedPublisher in this tenant. ' +
                'Publisher verification cannot be established from this response.'
            )
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }

    if ($Principals.Count -gt 0 -and @($Principals | Where-Object { $_.verifiedPublisher.verifiedPublisherId }).Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
            "None of the $($Principals.Count) blueprint principal(s) returns a populated verifiedPublisher ID. " +
            'This response cannot distinguish unverified publishers from unavailable publisher metadata; review publisher verification manually.'
        )
        return $null
    }

    $Foreign = @(
        $Principals | Where-Object {
            $Owner = [string]$_.appOwnerOrganizationId
            -not [string]::IsNullOrWhiteSpace($Owner) -and $Owner -ne $TenantId -and $Owner -notin $MicrosoftTenants
        }
    )
    $Unverified = @(
        $Foreign | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.verifiedPublisher.verifiedPublisherId) } |
            Select-Object @{ n = 'Blueprint principal'; e = { [string]$_.displayName } },
                @{ n = 'App ID'; e = { [string]$_.appId } },
                @{ n = 'Owner tenant'; e = { [string]$_.appOwnerOrganizationId } }
    )

    if ($Unverified.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            "Well done. All $($Foreign.Count) agent identity blueprint principal(s) from other organizations have a verified publisher " +
            "($($Principals.Count) blueprint principal(s) checked)."
        )
        return $true
    }

    $Result = @(
        "Found $($Unverified.Count) of $($Foreign.Count) agent identity blueprint principal(s) from other organizations with no verified publisher. " +
        'Confirm each vendor, then remove the ones you did not approve.'
        $Unverified | ConvertTo-AIGovMarkdownTable -Property 'Blueprint principal', 'App ID', 'Owner tenant'
    ) -join "`n`n"
    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
