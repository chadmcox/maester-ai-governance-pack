Agent risk records show when Microsoft Entra ID Protection sees signs that an agent is compromised. Entra keeps them for a limited time, so without exporting them you lose the history you need to investigate and to correlate with other logs.

#### Remediation action

In the Microsoft Entra admin center, go to **Entra ID** > **Monitoring & health** > **Diagnostic settings**. Edit
your setting (or select **Add diagnostic setting**), select **RiskyAgents** and **AgentRiskEvents**, choose a
destination such as a Log Analytics workspace, and select **Save**. Configuring it needs Security Administrator.

#### Related links

- [How To: Export risk data](https://learn.microsoft.com/entra/id-protection/howto-export-risk-data)
- [ID Protection for agents](https://learn.microsoft.com/entra/id-protection/concept-risky-agents)
- [Configure Microsoft Entra diagnostic settings](https://learn.microsoft.com/entra/identity/monitoring-health/howto-configure-diagnostic-settings)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1054)

<!--- Results --->
%TestResult%
