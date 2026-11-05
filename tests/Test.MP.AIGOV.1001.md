> [!WARNING]
> **NOT VALIDATED.** This test depends on the Copilot package catalog (Microsoft Agent 365 license)
> in addition to the usage report. It has not been run end to end against an Agent 365-licensed test
> tenant. Confirm the package catalog's `elementTypes` values and the usage report's agent-activity
> column name before relying on the result.

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
