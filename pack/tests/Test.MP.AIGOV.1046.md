Prompt Shields block prompts written to make the model ignore its rules. Without a content filter that blocks them, a user or attacker can jailbreak the model into producing harmful output or acting against your instructions.

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
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1046)

<!--- Results --->
%TestResult%
