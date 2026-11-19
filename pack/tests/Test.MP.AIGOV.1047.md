Checks that Azure OpenAI and Microsoft Foundry accounts keep their resource logs. Reads the accounts from
Azure Resource Graph (`Microsoft.CognitiveServices/accounts` of kind `OpenAI` or `AIServices`), then each
account's diagnostic settings (`{account}/providers/Microsoft.Insights/diagnosticSettings`) from Azure
Resource Manager. Resource logs aren't stored anywhere until a diagnostic setting sends them to Log
Analytics, a storage account, an event hub or a partner solution.

An account fails (Medium) when no diagnostic setting with a destination turns on every category in
`AIGOV.RequiredAiLogCategories` (default `Audit` and `RequestResponse`). The `allLogs` category group counts
for every category, and the `audit` group counts for `Audit`. Settings without a destination are ignored.
No accounts is a pass.

The account supports the `Audit`, `RequestResponse`, `Trace`, `AzureOpenAIRequestUsage` and
`ManagedNetworkEvent` categories. Add `Trace` or `AzureOpenAIRequestUsage` to the setting if you need them.

Frameworks: MCSB v2 AI-6 (monitoring and detection); Five Eyes Careful Adoption of Agentic AI (logging);
NIST 800-53 AU-2, AU-12.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.

#### Remediation action

In the Azure portal, open the Azure OpenAI or AI Services resource, go to **Monitoring** > **Diagnostic
settings**, and select **Add diagnostic setting**. Select the **allLogs** category group (or at least **Audit
Logs** and **Request and Response Logs**), select **Send to Log Analytics workspace**, and select **Save**.
Azure Policy can deploy this setting to every account.

#### Related links

- [Supported logs for Microsoft.CognitiveServices/accounts](https://learn.microsoft.com/azure/azure-monitor/reference/supported-logs/microsoft-cognitiveservices-accounts-logs)
- [Monitor Azure OpenAI](https://learn.microsoft.com/azure/ai-foundry/openai/how-to/monitor-openai)
- [MCSB v2: Artificial Intelligence Security (AI-6)](https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-artificial-intelligence-security)

<!--- Results --->
%TestResult%
