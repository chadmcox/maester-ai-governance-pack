Agent identities sign in and reach your data like users and apps do. Without a Conditional Access policy that covers them, you can't block risky agents, limit where they connect from or require stronger controls, so a compromised agent keeps its access.

#### Remediation action

Create at least one enabled Conditional Access policy that targets agent identities dynamically
(via `agentIdServicePrincipalFilter` or an agent risk condition), rather than relying solely on a
static `includeAgentIdServicePrincipals` ID list, and move any existing report-only agent-targeting
policy to enabled once you've confirmed it works as intended.

#### Related links

- [Target agent identities in Microsoft Entra Conditional Access policies](https://learn.microsoft.com/entra/identity/conditional-access/howto-target-agent-identities)
- [conditionalAccessClientApplications resource type](https://learn.microsoft.com/graph/api/resources/conditionalaccessclientapplications?view=graph-rest-beta)
- [conditionalAccessConditionSet resource type](https://learn.microsoft.com/graph/api/resources/conditionalaccessconditionset?view=graph-rest-beta)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1017)

<!--- Results --->
%TestResult%
