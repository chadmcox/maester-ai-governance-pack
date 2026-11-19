Checks that Azure OpenAI and Microsoft Foundry deployments only use models you approved. Reads the accounts
from Azure Resource Graph (`Microsoft.CognitiveServices/accounts` of kind `OpenAI` or `AIServices`), then each
account's deployments (`{account}/deployments`) from Azure Resource Manager, and compares each deployment's
model (`properties.model.name` and `version`) to `AIGOV.ApprovedModels`.

Each entry is a model name (`gpt-4.1`) or a name and version (`gpt-4o:2024-11-20`). Wildcards work
(`gpt-5*`, `text-embedding-3-*`), and matching ignores case. A deployment fails (Medium) when no entry
matches it.

The test **skips until you set** `AIGOV.ApprovedModels`, because only you know which models you approved:

```json
{
  "GlobalSettings": {
    "AIGOV.ApprovedModels": [ "gpt-4.1", "gpt-4o:2024-11-20", "text-embedding-3-*" ]
  }
}
```

Frameworks: MCSB v2 AI-1 (ensure use of approved models); OWASP ASI04 (agentic supply chain); NIST 800-53
CM-7.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.

#### Remediation action

Remove or replace deployments that use unapproved models, or add the model to `AIGOV.ApprovedModels` after
review. To block new ones, assign Azure Policy built-ins for allowed models (see the AI-1 policy mapping in
MCSB v2).

#### Related links

- [MCSB v2: Artificial Intelligence Security (AI-1)](https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-artificial-intelligence-security)
- [Deployments - List (Azure AI Services account management)](https://learn.microsoft.com/rest/api/aiservices/accountmanagement/deployments/list)

<!--- Results --->
%TestResult%
