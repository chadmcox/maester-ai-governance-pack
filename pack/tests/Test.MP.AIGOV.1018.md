Microsoft Entra ID Protection flags an agent as at risk when it sees signs of compromise. An agent left at risk keeps acting with its permissions until someone investigates, confirms it safe or blocks it.

#### Remediation action

Investigate each agent identity flagged `atRisk` and either remediate the underlying risk signal or
dismiss it once reviewed. Investigate `confirmedCompromised` agents immediately — they represent a
risk investigation that has already concluded against the agent.

#### Related links

- [Get-MgBetaRiskyAgent](https://learn.microsoft.com/powershell/module/microsoft.graph.beta.identity.signins/get-mgbetariskyagent?view=graph-powershell-beta)
- [Microsoft Graph permissions reference](https://learn.microsoft.com/graph/permissions-reference)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1018)

<!--- Results --->
%TestResult%
