> [!NOTE]
> **Not yet validated live.** Built from the documented `externalConnection` schema
> (`state`, `description`, `configuration.authorizedAppIds`); confirm against a tenant with at least
> one synced Copilot connector.

Checks the synced (indexed) Copilot connectors that users can search, read from
`GET /external/connections`. A connection is in scope when its `state` is `ready`, or `limitExceeded`
(the index is full, but what's already indexed is still searchable). Draft and obsolete connections
are skipped and counted.

| Severity | Check |
| --- | --- |
| Medium | `configuration.authorizedAppIds` lists an app with no service principal in this tenant |
| Medium | `configuration.authorizedAppIds` lists an app owned by another organization (not this tenant, not Microsoft). That app can write content users then get back from Copilot. |
| Low | `state` is `limitExceeded`, so answers draw on only part of the source |
| Low | The connection has no description |

The result always includes a table of every connector users can search, so it doubles as the
inventory.

**Not covered (Graph doesn't expose it):** the staged-rollout audience and per-item access rules,
such as a gallery connector set so every user sees all content. Check those in the Microsoft 365
admin center under **Copilot > Connectors > Your connections**. Federated (live, MCP-based)
connectors aren't external connections; MP.AIGOV.1007, 1008, 1010, 1011 and 1016 cover them through
the agent catalog.

#### Remediation action

- Remove apps you can't identify, or that belong to a vendor you haven't reviewed, from the
  connection's authorized apps.
- For `limitExceeded`, raise the index quota or narrow what the connector indexes.
- Give each connection a description that says what it holds and who it's for.

#### Related links

- [externalConnection resource type](https://learn.microsoft.com/graph/api/resources/externalconnectors-externalconnection?view=graph-rest-1.0)
- [View connection details](https://learn.microsoft.com/microsoft-365/copilot/connectors/view-details)

<!--- Results --->
%TestResult%
