Checks that every enabled agent identity still has an active sponsor. Reads
`GET /servicePrincipals/microsoft.graph.agentIdentity`, then each enabled agent identity's
`/microsoft.graph.agentIdentity/sponsors`. A sponsor is active when it is a group, or a user whose `accountEnabled`
isn't false.

An enabled agent identity fails when it has no sponsors left or every sponsor is disabled. Entra requires a
sponsor when an agent identity is created, so this usually means a sponsor left without a Lifecycle Workflows
sponsor transfer.

`MT.1205` covers sponsors on blueprints and blueprint principals only; `MP.AIGOV.1004` flags exactly one sponsor with
zero owners.

Framework: CISA draft SCuBA agent baseline MS.SI.3.1 (every agent SHALL have a sponsor and an owner); NIST 800-53 AC-2.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.

#### Remediation action

Assign an active sponsor to each agent identity, or disable it. To stop this recurring, add the *Transfer agent
identity sponsorships to manager* task to your mover and leaver Lifecycle Workflows.

#### Related links

- [Owners, sponsors and managers in Microsoft Entra Agent ID](https://learn.microsoft.com/entra/agent-id/agent-owners-sponsors-managers)
- [Agent identity sponsor tasks in Lifecycle Workflows](https://learn.microsoft.com/entra/id-governance/agent-sponsor-tasks)

<!--- Results --->
%TestResult%
