function Get-AIGovMcpTool {
    <#
    .SYNOPSIS
    Returns one row per MCP tool defined in a Copilot catalog package.
    .DESCRIPTION
    Reads GET /copilot/admin/catalog/packages/{id} for each piped package and parses every
    AgentConnectors element definition (a JSON string) for
    toolSource.remoteMcpServer.mcpToolDescription.tools, the same path MP.AIGOV.1008, 1011 and 1016
    read. Each tool row carries PackageId, PackageName, ServerUrl, ToolName, Description,
    InputSchema, Annotations and Failed = $false.

    A package whose detail call fails, or whose definition can't be parsed, yields one row with
    Failed = $true and no tool, so the caller can count what it couldn't evaluate.
    .EXAMPLE
    $Packages | Get-AIGovMcpTool | Where-Object { -not $_.Failed }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Package
    )

    process {
        $PackageId = [string]$Package.id
        if ([string]::IsNullOrWhiteSpace($PackageId)) { return }
        $PackageName = [string]$Package.displayName

        try {
            $Detail = Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "copilot/admin/catalog/packages/$PackageId"
        } catch {
            Write-Verbose "Could not read package $PackageId`: $($_.Exception.Message)"
            $Package | Select-Object @{ n = 'PackageId'; e = { $PackageId } }, @{ n = 'PackageName'; e = { $PackageName } }, @{ n = 'Failed'; e = { $true } }
            return
        }

        $Definitions = @(
            $Detail.elementDetails |
                Where-Object { $_.elementType -eq 'AgentConnectors' } |
                ForEach-Object { @($_.elements) } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_.definition) }
        )

        foreach ($Element in $Definitions) {
            try {
                $Server = ($Element.definition | ConvertFrom-Json -ErrorAction Stop).toolSource.remoteMcpServer
            } catch {
                Write-Verbose "Could not parse an AgentConnectors definition for package $PackageId`: $_"
                $Package | Select-Object @{ n = 'PackageId'; e = { $PackageId } }, @{ n = 'PackageName'; e = { $PackageName } }, @{ n = 'Failed'; e = { $true } }
                continue
            }

            @($Server.mcpToolDescription.tools) | Where-Object { $null -ne $_ } | Select-Object `
                @{ n = 'PackageId'; e = { $PackageId } },
                @{ n = 'PackageName'; e = { $PackageName } },
                @{ n = 'ServerUrl'; e = { [string]$Server.mcpServerUrl } },
                @{ n = 'ToolName'; e = { [string]$_.name } },
                @{ n = 'Description'; e = { [string]$_.description } },
                @{ n = 'InputSchema'; e = { $_.inputSchema } },
                @{ n = 'Annotations'; e = { $_.annotations } },
                @{ n = 'Failed'; e = { $false } }
        }
    }
}
