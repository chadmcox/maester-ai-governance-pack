Without exported logs you can't see who called a model, what was asked or how it was used. You need these logs to investigate misuse, prove compliance and spot attacks such as prompt injection or data theft.

#### Remediation action

In the Azure portal, open the Azure OpenAI or AI Services resource, go to **Monitoring** > **Diagnostic
settings**, and select **Add diagnostic setting**. Select the **allLogs** category group (or at least **Audit
Logs** and **Request and Response Logs**), select **Send to Log Analytics workspace**, and select **Save**.
Azure Policy can deploy this setting to every account.

#### Related links

- [Supported logs for Microsoft.CognitiveServices/accounts](https://learn.microsoft.com/azure/azure-monitor/reference/supported-logs/microsoft-cognitiveservices-accounts-logs)
- [Monitor Azure OpenAI](https://learn.microsoft.com/azure/ai-foundry/openai/how-to/monitor-openai)
- [MCSB v2: Artificial Intelligence Security (AI-6)](https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-artificial-intelligence-security)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1047)

<!--- Results --->
%TestResult%
