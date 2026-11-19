Checks the content filters on Azure OpenAI and Microsoft Foundry model deployments. Reads the accounts from
Azure Resource Graph (`Microsoft.CognitiveServices/accounts` of kind `OpenAI` or `AIServices`), then each
account's deployments (`{account}/deployments`) and content filters (`{account}/raiPolicies`) from Azure
Resource Manager. A text model deployment fails (Medium) when:

- it has no content filter (`raiPolicyName` is empty);
- its content filter doesn't turn on **and block** Prompt Shields for user prompts (the `Jailbreak` filter).
  Annotate-only still lets the attack reach the model;
- with `AIGOV.RequireIndirectAttackFilter` set to `true`, its content filter doesn't turn on and block Prompt
  Shields for indirect attacks (instructions hidden in documents, email or web pages the model reads).

Embedding, speech and image models are left out. A deployment on `Microsoft.DefaultV2` that the account
doesn't list is counted as passing, because Microsoft documents Prompt Shields for user prompts as on by
default. The filter's `Mode` is shown for information: `Asynchronous_filter` lets streamed completions
return before filtering finishes. No deployments is a pass.

Frameworks: MCSB v2 AI-2 (multi-layered content filtering); OWASP LLM01 (prompt injection) and ASI01 (agent
goal hijack); NIST 800-53 SI-10.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). The control names
> (`Jailbreak` or "user prompt attack"; "indirect" or "document attack") are matched by pattern, and a
> control counts as blocking when `blocking` is true or `action` is `BLOCKING`. Both still need a live check
> against a real `raiPolicies` response. Run it against your tenant and check the result before relying on it.

#### Remediation action

In the Foundry portal, go to your project, select **Build** > **Guardrails** > **Create guardrail**. Add a
**User prompt attack** control with the **Annotate and block** action (and a **Document attack** control if
your app passes documents or tool results to the model). Assign the guardrail to each model deployment. In
Foundry (classic) the same setting is **Guardrails + controls** > **Content filters** > **Prompt Shields for
jailbreak**. A guardrail is stored as the deployment's `raiPolicyName`.

#### Related links

- [Configure guardrails and controls in Microsoft Foundry](https://learn.microsoft.com/azure/foundry/guardrails/how-to-create-guardrails)
- [Configure content filters](https://learn.microsoft.com/azure/ai-foundry/openai/how-to/content-filters)
- [Prompt Shields](https://learn.microsoft.com/azure/ai-services/content-safety/concepts/jailbreak-detection)
- [MCSB v2: Artificial Intelligence Security (AI-2)](https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-artificial-intelligence-security)

<!--- Results --->
%TestResult%
