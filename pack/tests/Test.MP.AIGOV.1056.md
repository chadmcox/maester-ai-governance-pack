A hosted agent can call any host its egress rules let through. In Audit mode, or with a default action of Allow, an agent steered by a bad prompt or tool result can send your data to any site on the internet, and nothing stops it.

#### Remediation action

In the Foundry portal, edit the guardrail your hosted agent uses and expand the **Network** control. Set
**Outbound requests** to **Deny**, add **Allow** rules only for the hosts the agent needs, and switch each rule
from **Audit** to **Enforce** once you've reviewed the egress decisions. Remove any Allow rule with no host or `*`.
Running sessions don't reload the policy: deploy a new agent version and start a new session.

#### Related links

- [Add guardrails to a hosted agent: network egress controls](https://learn.microsoft.com/azure/foundry/agents/how-to/add-hosted-agent-guardrails#network-egress-controls)
- [Govern hosted agent egress with Azure Policy (preview)](https://learn.microsoft.com/azure/foundry/agents/how-to/govern-hosted-agent-egress-azure-policy)
- [MCSB v2: Artificial Intelligence Security (AI-4)](https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-artificial-intelligence-security)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1056)

<!--- Results --->
%TestResult%
