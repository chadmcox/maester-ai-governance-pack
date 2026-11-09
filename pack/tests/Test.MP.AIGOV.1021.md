> [!NOTE]
> **Not yet validated** against a live tenant. Ported from chadmcox/Copilot "Agent and Tools Health Check".

Checks the groups that agents and tools are assigned to (who can use or install them). Each group decides
who gets the agent, so someone has to own its membership.

| Severity | Condition |
| --- | --- |
| Medium | An assigned group no longer exists. |
| Medium | An assigned group has fewer than `MinOwnerCount` owners (default 2). |
| Low | An assigned group has no description. |

Agents assigned directly to users are `MP.AIGOV.1003`.

#### Remediation action

Reassign agents from deleted groups to the right group, add at least two owners to each group, and describe
each group and the agent or tool it's for.

#### Related links

- [Get a Copilot package](https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/package/copilotpackages-get)

<!--- Results --->
%TestResult%
