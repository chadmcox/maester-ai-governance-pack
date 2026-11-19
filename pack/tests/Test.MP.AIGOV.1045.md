Azure OpenAI and Foundry accounts that accept API keys, are open to the internet or aren't covered by Defender for AI can be reached by anyone with a leaked key, and attacks on them go unseen.

#### Remediation action

Set `disableLocalAuth` to true and move callers to Entra ID (managed identities), restrict network access with
private endpoints or network rules, and turn on Defender for AI Services for the subscription.

#### Related links

- [Disable local authentication in Azure AI services](https://learn.microsoft.com/azure/ai-services/disable-local-auth)
- [AI threat protection in Defender for Cloud](https://learn.microsoft.com/azure/defender-for-cloud/ai-threat-protection)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1045)

<!--- Results --->
%TestResult%
