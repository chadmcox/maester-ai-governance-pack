> [!NOTE]
> **Validated** 2026-11-05 against a real Microsoft 365 test tenant (Graph only, no Agent 365
> license). The run passed clean: no classic Copilot Studio service principal in the test tenant was
> missing an Agent Identity or Blueprint Principal registration.

Checks for classic Copilot Studio service principals — tagged `AgentCreatedBy:CopilotStudio`,
`AgenticApp`, `AIAgentBuilder`, `AgenticInstance`, or a `power-virtual-agents-*` tag — that have no
corresponding Agent Identity or Agent Identity Blueprint Principal registration. This describes a
current state, not a required migration: Microsoft has not published an in-place way to convert a
classic service principal into an Agent ID.

Graph only — this test does not need a Microsoft Agent 365 license.

#### Remediation action

For each flagged agent, decide its disposition: retire it if unused, recreate it with Agent ID if
lightly used, or keep it running as-is (with its own sponsor/owner hygiene) if it is a busy production
agent until Microsoft ships an automated migration path.

#### Related links

- [List servicePrincipals](https://learn.microsoft.com/graph/api/serviceprincipal-list?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
