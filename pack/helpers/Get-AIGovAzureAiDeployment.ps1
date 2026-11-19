function Get-AIGovAzureAiDeployment {
    <#
    .SYNOPSIS
    Returns the model deployments of Azure OpenAI and AI Services accounts, one row per deployment.
    .DESCRIPTION
    Reads GET {account id}/deployments (all pages) from Azure Resource Manager for each account piped in (from
    Get-AIGovAzureAiAccount). Each row carries the account, the deployment name, the model name, version,
    format and publisher, and the content filter (RAI policy) name.

    An account Maester can't read (401 or 403, or an error) comes back as one row with ReadError set and
    no Deployment, so callers can tell "no deployments" apart from "couldn't look".
    .PARAMETER Account
    An account row from Get-AIGovAzureAiAccount (id, name, subscriptionId, resourceGroup, kind).
    .EXAMPLE
    Get-AIGovAzureAiAccount | Get-AIGovAzureAiDeployment
    .LINK
    https://learn.microsoft.com/rest/api/aiservices/accountmanagement/deployments/list
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Account
    )

    process {
        $AccountId = [string]$Account.id
        $Base = @(
            @{ n = 'Account'; e = { [string]$Account.name } }
            @{ n = 'AccountId'; e = { $AccountId } }
            @{ n = 'Kind'; e = { [string]$Account.kind } }
            @{ n = 'Subscription'; e = { [string]$Account.subscriptionId } }
            @{ n = 'Resource group'; e = { [string]$Account.resourceGroup } }
        )

        $Deployments = $null
        $ReadError = $null
        try {
            $Deployments = Invoke-AIGovAzureList -RelativeUri "$AccountId/deployments" -ApiVersion '2024-10-01'
            if ($null -eq $Deployments) { $ReadError = 'no access to the deployments' }
        } catch {
            $ReadError = "couldn't read the deployments: $($_.Exception.Message)"
        }

        if ($ReadError) {
            $Account | Select-Object ($Base + @(
                @{ n = 'Deployment'; e = { $null } }
                @{ n = 'ReadError'; e = { $ReadError } }
            ))
            return
        }

        foreach ($Deployment in $Deployments) {
            $Deployment | Select-Object ($Base + @(
                @{ n = 'Deployment'; e = { [string]$_.name } }
                @{ n = 'Model'; e = { [string]$_.properties.model.name } }
                @{ n = 'Version'; e = { [string]$_.properties.model.version } }
                @{ n = 'Format'; e = { [string]$_.properties.model.format } }
                @{ n = 'Publisher'; e = { [string]$_.properties.model.publisher } }
                @{ n = 'RaiPolicy'; e = { [string]$_.properties.raiPolicyName } }
                @{ n = 'ReadError'; e = { $null } }
            ))
        }
    }
}
