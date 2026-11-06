> [!NOTE]
> **Validated** 2026-11-05 against a real Microsoft 365 test tenant (Graph only, no Agent 365
> license). The run correctly found 10 real Agent Identity / Agent Identity Blueprint objects with
> exactly one sponsor and zero owners, with accurate object IDs, display names, and object types in
> the result table.

Checks every Agent Identity, Agent Identity Blueprint, and Blueprint Principal for exactly one
assigned sponsor and zero owners. A sponsor provides organizational accountability for why the agent
exists; an owner can administer the object itself. An object with one sponsor and no owners is a
single point of failure: if that one person leaves or is disabled, nobody with a formal relationship
to the object remains.

Graph only — this test does not need a Microsoft Agent 365 license.

#### Remediation action

Add at least a second sponsor, or assign an owner, to every flagged object so no single person's
departure leaves it unaccounted for.

#### Related links

- [List agentIdentityBlueprint sponsors](https://learn.microsoft.com/graph/api/agentidentityblueprint-list-sponsors?view=graph-rest-1.0)
- [List servicePrincipal owners](https://learn.microsoft.com/graph/api/serviceprincipal-list-owners?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
