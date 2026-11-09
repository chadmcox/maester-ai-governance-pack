function Test-MPAIGOV1033 {
    <#
    .SYNOPSIS
    Finds Copilot connectors users can search whose content can be written by outside apps, or that are hard to identify.
    .DESCRIPTION
    Reads the synced (indexed) Copilot connectors, GET /external/connections. Only connections users can
    search are in scope: state 'ready', or 'limitExceeded' (the index is full but what's already indexed is
    still searchable). Connections in 'draft' or 'obsolete' are skipped and counted.

    For each connection in scope:
      - Medium: configuration.authorizedAppIds lists an app with no service principal in this tenant.
        The grant outlives the app, and nobody here can review what the app is.
      - Medium: configuration.authorizedAppIds lists an app owned by another organization (not this tenant
        and not Microsoft). That app can write content that users then get back from Copilot, which makes
        it a path for planted or poisoned content.
      - Low: state is limitExceeded, so users get answers from part of the source only.
      - Low: the connection has no description, so admins (and Copilot's source selection) can't tell what
        it holds.

    The result always lists every connection users can search, so it doubles as the inventory.

    Not covered, because Graph doesn't expose it: the connector's staged-rollout audience and the
    per-item access rules (for example a gallery connector set so every user sees all content). Review
    those under Copilot > Connectors > Your connections in the Microsoft 365 admin center. Federated (live,
    MCP-based) connectors are not external connections; MP.AIGOV.1007, 1008, 1010, 1011 and 1016 cover them
    through the agent catalog.
    .EXAMPLE
    Test-MPAIGOV1033
    .LINK
    https://learn.microsoft.com/graph/api/resources/externalconnectors-externalconnection?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1033',
        Title        = 'Copilot connectors users can search should only take content from apps you govern',
        Product      = 'entra',
        Feature      = 'connectors',
        Area         = 'ai',
        ResourceType = 'Tenant',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:SI-7',
        Permission   = 'Graph:Application:ExternalConnection.Read.All|Graph:Application:Application.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Microsoft's own tenant: apps it owns are first-party and aren't treated as outside apps.
    $MicrosoftTenantIds = @('f8cdef31-a31e-4b4a-93e4-5f571e91255a', '72f988bf-86f1-41af-91ab-2d7cd011db47')

    try {
        Write-Verbose 'Reading Copilot connectors (external connections).'
        $Connections = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'external/connections' `
                -Select @('id', 'name', 'description', 'state', 'connectorId', 'configuration')
        )
    } catch {
        $ErrorRecord = $_
    }
    if ($ErrorRecord) {
        if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (
                "Couldn't read Copilot connectors (403). Grant ExternalConnection.Read.All and re-run this check."
            )
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
        }
        return $null
    }

    $Connections = @($Connections | Where-Object { $_ -and -not [string]::IsNullOrWhiteSpace([string]$_.id) })
    $Searchable = @($Connections | Where-Object { [string]$_.state -match '^(?i)(ready|limitExceeded)$' })
    $NotSearchableCount = $Connections.Count - $Searchable.Count
    Write-Verbose "Found $($Connections.Count) connection(s); $($Searchable.Count) users can search."

    if ($Searchable.Count -eq 0) {
        $Result = 'Well done. No Copilot connector is searchable by users.'
        if ($NotSearchableCount -gt 0) { $Result += " $NotSearchableCount draft or obsolete connection(s) skipped." }
        Add-MtTestResultDetail -Result $Result
        return $true
    }

    $TenantId = $null
    try {
        $Org = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'organization' -Select @('id'))
        $TenantId = [string]$Org[0].id
    } catch {
        Write-Verbose "Couldn't read the tenant ID, so the outside-app rule is skipped: $($_.Exception.Message)"
    }

    $Findings = [System.Collections.Generic.List[pscustomobject]]::new()
    $AppCache = @{}
    $UnreadApps = 0
    foreach ($Connection in $Searchable) {
        $Name = [string]$Connection.name
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = [string]$Connection.id }

        foreach ($AppId in @($Connection.configuration.authorizedAppIds)) {
            $AppId = [string]$AppId
            if ([string]::IsNullOrWhiteSpace($AppId)) { continue }

            if (-not $AppCache.ContainsKey($AppId)) {
                try {
                    $AppCache[$AppId] = @(
                        Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'servicePrincipals' `
                            -Filter "appId eq '$AppId'" -Select @('id', 'displayName', 'appOwnerOrganizationId')
                    ) | Select-Object -First 1
                } catch {
                    Write-Verbose "Couldn't look up authorized app $AppId`: $($_.Exception.Message)"
                    $AppCache[$AppId] = 'unread'
                }
            }
            $App = $AppCache[$AppId]

            if ($App -is [string] -and $App -eq 'unread') {
                $UnreadApps++
                continue
            }
            if ($null -eq $App) {
                $Findings.Add([pscustomobject]@{
                    Connection = $Name; Severity = 'Medium'; Check = "Authorized app $AppId has no service principal in this tenant"
                    Fix = 'Remove the app from the connection, or find out what it is before keeping it.'
                })
                continue
            }

            $Owner = [string]$App.appOwnerOrganizationId
            if ($TenantId -and -not [string]::IsNullOrWhiteSpace($Owner) -and
                $Owner -ne $TenantId -and $Owner -notin $MicrosoftTenantIds) {
                $Findings.Add([pscustomobject]@{
                    Connection = $Name; Severity = 'Medium'
                    Check = "Outside app '$([string]$App.displayName)' can write content users get from Copilot"
                    Fix = 'Confirm the vendor and what it indexes, or remove it from authorizedAppIds.'
                })
            }
        }

        if ([string]$Connection.state -match '^(?i)limitExceeded$') {
            $Findings.Add([pscustomobject]@{
                Connection = $Name; Severity = 'Low'; Check = 'Index limit exceeded'
                Fix = 'Raise the index quota or narrow what the connector indexes, so answers draw on the whole source.'
            })
        }
        if ([string]::IsNullOrWhiteSpace([string]$Connection.description)) {
            $Findings.Add([pscustomobject]@{
                Connection = $Name; Severity = 'Low'; Check = 'No description'
                Fix = 'Describe what the connection holds and who it is for.'
            })
        }
    }

    $Notes = ''
    if ($NotSearchableCount -gt 0) { $Notes += " $NotSearchableCount draft or obsolete connection(s) skipped." }
    if (-not $TenantId) { $Notes += " Couldn't read the tenant ID, so outside-owned apps weren't checked." }
    if ($UnreadApps -gt 0) { $Notes += " $UnreadApps authorized app lookup(s) failed and aren't reflected here." }

    $Inventory = "`n`n**Connectors users can search**`n`n| Connection | ID | State | Authorized apps |`n| --- | --- | --- | --- |"
    foreach ($Connection in $Searchable) {
        $Name = [string]$Connection.name
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
        $AppCount = @($Connection.configuration.authorizedAppIds | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count
        $Inventory += "`n| $(ConvertTo-AIGovMarkdownCell -Text $Name) | $(ConvertTo-AIGovMarkdownCell -Text $Connection.id) | " +
            "$(ConvertTo-AIGovMarkdownCell -Text $Connection.state) | $AppCount |"
    }

    if ($Findings.Count -eq 0) {
        Add-MtTestResultDetail -Result (
            "Well done. $($Searchable.Count) Copilot connector(s) users can search, none with an issue.$Notes$Inventory"
        )
        return $true
    }

    $Rank = @{ High = 0; Medium = 1; Low = 2 }
    $Ordered = @($Findings | Sort-Object @{ Expression = { $Rank[$_.Severity] } }, Connection)
    $Result = "Found $($Findings.Count) issue(s) across $($Searchable.Count) Copilot connector(s) users can search.$Notes"
    $Result += "`n`n| Connection | Severity | Check | Fix |`n| --- | --- | --- | --- |"
    foreach ($Item in $Ordered) {
        $Result += "`n| $(ConvertTo-AIGovMarkdownCell -Text $Item.Connection) | $($Item.Severity) | " +
            "$(ConvertTo-AIGovMarkdownCell -Text $Item.Check) | $(ConvertTo-AIGovMarkdownCell -Text $Item.Fix) |"
    }
    $Result += $Inventory

    Add-MtTestResultDetail -Result $Result -Severity $Ordered[0].Severity
    return $false
}
