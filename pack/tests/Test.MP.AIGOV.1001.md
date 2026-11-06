> [!NOTE]
> **Validated** 2026-11-05 against a real Microsoft 365 test tenant (F7-licensed; the package
> catalog API was reachable with `CopilotPackages.Read.All` alone — no separate Agent 365 license
> was required to reach it in this tenant). The run correctly **Skipped** with
> "the package catalog reports no agents, so adoption has nothing to measure" because this tenant's
> catalog had zero agents. The adoption-threshold comparison itself was not exercised; re-validate
> that branch once a tenant with at least one agent and usage data is available.

Checks whether Microsoft 365 Copilot agent catalog adoption is at or above a configurable threshold
(default 5%) over the fixed D90 report period. Only runs when the package catalog reports at least
one agent. Skips when fewer than 20 users are reported, or when no usage-report column matches the
undocumented `*Agent*Activity*` name pattern.

Low adoption after agents have been published for a while can mean the agents solve the wrong
problem, are hard to find, or were never announced to the people they were built for.

#### Remediation action

Confirm the agent catalog is discoverable (clear names, sensible group targeting — see
`MP.AIGOV.1003`), check with agent owners whether the agents still solve a real problem, and consider
retiring or re-announcing agents that remain below the adoption threshold after a reasonable
grace period.

#### Related links

- [Get Microsoft 365 Copilot usage report](https://learn.microsoft.com/graph/api/reportroot-getmicrosoft365copilotusageuserdetail?view=graph-rest-beta)
- [List Copilot packages](https://learn.microsoft.com/graph/api/copilotadmin-list-packages?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
