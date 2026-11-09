> [!NOTE]
> **Not yet validated** against a live tenant. Ported from chadmcox/Copilot "Agent and Tools Health Check".

Older Copilot Studio agents run as ordinary service principals, without the sponsor and lifecycle controls
of Agent ID. `MP.AIGOV.1005` lists them; this test checks the ones that need attention first.

| Severity | Condition |
| --- | --- |
| Medium | No owner. |
| Low | Enabled, created more than `StaleDays` ago (default 180), and no sign-in in `StaleDays` or none recorded. |

The sign-in check needs AuditLog.Read.All. If sign-in activity can't be read, it's skipped and the result
says so.

#### Remediation action

There's no in-place migration to Agent ID. Retire unused ones instead of recreating them. Give the rest an
owner, then recreate lightly used ones with Agent ID; for busy production agents, Microsoft says to wait for
an automated migration path.

#### Related links

- [Agent identities, service principals and applications](https://learn.microsoft.com/entra/agent-id/agent-service-principals)

<!--- Results --->
%TestResult%
