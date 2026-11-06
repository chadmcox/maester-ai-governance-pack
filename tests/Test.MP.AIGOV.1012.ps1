function Test-MPAIGOV1012 {
    <#
    .SYNOPSIS
    Finds agent skills with a weak frontmatter description, or exposed to Copilot inside a package
    available or deployed tenant-wide.
    .DESCRIPTION
    Microsoft's Copilot Cowork plugin packaging guide describes an agentSkills manifest section
    (SKILL.md-style packages); this is confirmed live (2026-11-06) as a real elementTypes value (32
    packages in the test tenant). The per-package detail call, GET
    /copilot/admin/catalog/packages/{id}, returns an elementDetails entry with elementType
    'AgentSkills', whose elements[].definition (a JSON string) contains folder,
    expose_skill_to_copilot (boolean), and frontmatter.{name,description} -- all confirmed live
    against a real package ("Moody's Credit MCP"'s "earnings-brief" skill). This test flags a skill
    if either condition holds: its frontmatter.description is empty or shorter than a configurable
    -MinDescriptionLength (default 40 characters) -- Copilot uses this text to decide when to invoke
    the skill, so a missing or vague one risks the skill firing on the wrong request, or never firing
    at all; or expose_skill_to_copilot is true AND the package is available or deployed tenant-wide
    (the same signal MP.AIGOV.1007 and MP.AIGOV.1011 use) -- a skill explicitly exposed to Copilot,
    reachable by everyone by default, should get the same deliberate, scoped rollout review as any
    other tenant-wide tool. Reading this endpoint may require a Microsoft Agent 365 license depending
    on tenant.
    .EXAMPLE
    Test-MPAIGOV1012
    .EXAMPLE
    Test-MPAIGOV1012 -MinDescriptionLength 60
    .LINK
    https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1012',
        Title        = 'Agent skill should have a clear description, and should not be exposed to Copilot tenant-wide without review',
        Product      = 'entra',
        Feature      = 'tools',
        Area         = 'ai',
        ResourceType = 'Agent',
        Severity     = 'Medium',
        Control      = 'nist-800-53-r5:CM-7',
        Permission   = 'Graph:Application:CopilotPackages.Read.All',
        Service      = 'Graph',
        Lifecycle    = 'Preview',
        LongRunning
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Minimum frontmatter description length (in characters) before a skill is considered to have
        # an adequately descriptive trigger condition. Defaults to 40.
        [Parameter(Mandatory = $false)]
        [int]$MinDescriptionLength = 40
    )

    try {
        Write-Verbose 'Reading the Copilot package catalog for packages with agent skill elements.'
        $Packages = @(
            Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri 'copilot/admin/catalog/packages' `
                -Select @('id', 'displayName', 'elementTypes', 'availableTo', 'deployedTo')
        )
    } catch {
        $ErrorRecord = $_
    }
    if ($ErrorRecord) {
        if ($ErrorRecord.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (Get-AIGovPackageCatalogSkipMessage)
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $ErrorRecord
        }
        return $null
    }

    $SkillPackages = @($Packages | Where-Object { $_.elementTypes -contains 'AgentSkills' })
    Write-Verbose "Found $($SkillPackages.Count) package(s) with an agent skill element."

    $FlaggedSkills = [System.Collections.Generic.List[pscustomobject]]::new()
    $FailedPackageCount = 0
    foreach ($Package in $SkillPackages) {
        $PackageId = [string]$Package.id
        if ([string]::IsNullOrWhiteSpace($PackageId)) { continue }

        $IsTenantWide = ([string]$Package.availableTo -match '(?i)allowedForAll') -or
            ([string]$Package.deployedTo -match '(?i)acquiredForAll')

        try {
            $Detail = Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "copilot/admin/catalog/packages/$PackageId"
        } catch {
            Write-Verbose "Skipping package $PackageId after a detail-read error: $($_.Exception.Message)"
            $FailedPackageCount++
            continue
        }

        $AgentSkillDetails = @($Detail.elementDetails | Where-Object { $_.elementType -eq 'AgentSkills' })
        $PackageHadParseFailure = $false
        foreach ($SkillDetail in $AgentSkillDetails) {
            foreach ($Element in @($SkillDetail.elements)) {
                if ([string]::IsNullOrWhiteSpace($Element.definition)) { continue }

                try {
                    $Parsed = $Element.definition | ConvertFrom-Json -ErrorAction Stop
                } catch {
                    Write-Verbose "Could not parse an AgentSkills definition for package $PackageId`: $_"
                    $PackageHadParseFailure = $true
                    continue
                }

                $SkillName = [string]$Parsed.frontmatter.name
                $Description = [string]$Parsed.frontmatter.description
                $ExposeToCopilot = $Parsed.expose_skill_to_copilot -eq $true

                $Reasons = [System.Collections.Generic.List[string]]::new()
                if ($Description.Length -lt $MinDescriptionLength) {
                    $Reasons.Add("description is $(if ($Description.Length -eq 0) { 'empty' } else { "only $($Description.Length) character(s)" })")
                }
                if ($ExposeToCopilot -and $IsTenantWide) {
                    $Reasons.Add('exposed to Copilot in a tenant-wide package')
                }
                if ($Reasons.Count -eq 0) { continue }

                $FlaggedSkills.Add([pscustomobject]@{
                    PackageId   = $PackageId
                    DisplayName = [string]$Package.displayName
                    SkillName   = $SkillName
                    Reasons     = ($Reasons -join '; ')
                })
            }
        }
        if ($PackageHadParseFailure) { $FailedPackageCount++ }
    }

    if ($SkillPackages.Count -gt 0 -and $FailedPackageCount -eq $SkillPackages.Count) {
        Add-MtTestResultDetail -SkippedBecause Error -Result (
            "Could not evaluate any of the $($SkillPackages.Count) package(s) with an agent skill element " +
            "-- every detail call or definition parse failed. See verbose logs for details."
        )
        return $null
    }

    if ($FlaggedSkills.Count -eq 0) {
        $Result = "Well done. No agent skill has a weak description or an unreviewed tenant-wide Copilot " +
            "exposure ($($SkillPackages.Count) package(s) with an agent skill element checked)."
        if ($FailedPackageCount -gt 0) {
            $Result += "`n`n$FailedPackageCount package(s) could not be evaluated (detail-read or parse error) " +
                'and are not reflected in this result.'
        }
        Add-MtTestResultDetail -Result $Result
        return $true
    }

    $Result = "Found $($FlaggedSkills.Count) agent skill(s) with a weak description or an unreviewed tenant-wide Copilot exposure."
    if ($FailedPackageCount -gt 0) {
        $Result += " $FailedPackageCount package(s) could not be evaluated (detail-read or parse error) " +
            'and are not reflected below.'
    }
    $Result += "`n`n| Package ID | Display name | Skill name | Reason(s) |"
    $Result += "`n| --- | --- | --- | --- |"
    foreach ($Item in $FlaggedSkills) {
        $Name = [string]$Item.DisplayName
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = '(unnamed)' }
        $Name = [System.Net.WebUtility]::HtmlEncode($Name) -replace '\|', '&#124;'
        $Name = $Name -replace "`r?`n", ' '
        $SkillName = [string]$Item.SkillName
        if ([string]::IsNullOrWhiteSpace($SkillName)) { $SkillName = '(unnamed)' }
        $SkillName = [System.Net.WebUtility]::HtmlEncode($SkillName) -replace '\|', '&#124;'
        $SkillName = $SkillName -replace "`r?`n", ' '
        $Result += "`n| $($Item.PackageId) | $Name | $SkillName | $($Item.Reasons) |"
    }

    Add-MtTestResultDetail -Result $Result -Severity 'Medium'
    return $false
}
