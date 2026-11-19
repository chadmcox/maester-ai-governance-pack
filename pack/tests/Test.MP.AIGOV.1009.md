When a blueprint's secret or certificate expires, every agent built from it stops signing in, and the outage often hits users before anyone notices. Rotating credentials before they expire keeps agents running and avoids rushed fixes.

#### Remediation action

Rotate the client secret or certificate (or migrate to a federated identity credential) before it
expires, to avoid an unplanned outage when the agent identity loses the ability to authenticate.

#### Related links

- [List agentIdentityBlueprints](https://learn.microsoft.com/graph/api/agentidentityblueprint-list?view=graph-rest-1.0)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1009)

<!--- Results --->
%TestResult%
