function Get-AIGovAzureAiAccount {
    <#
    .SYNOPSIS
    Returns the Azure OpenAI and Azure AI Services accounts Maester can read, from Azure Resource Graph.
    .DESCRIPTION
    Microsoft.CognitiveServices/accounts of kind OpenAI or AIServices: the resources behind Azure OpenAI
    and Microsoft Foundry. Used by MP.AIGOV.1046, 1047 and 1048. Errors are left to the caller.
    .EXAMPLE
    Get-AIGovAzureAiAccount
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    $Query = @'
Resources
| where type =~ 'microsoft.cognitiveservices/accounts'
| where kind in~ ('OpenAI', 'AIServices')
| project id, name, subscriptionId, resourceGroup, kind
'@
    @(Invoke-MtAzureResourceGraphRequest -Query $Query | Where-Object { $null -ne $_ })
}
