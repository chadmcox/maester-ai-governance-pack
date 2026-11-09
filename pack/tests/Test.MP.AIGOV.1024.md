> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Passed**: there are no classic Copilot Studio service principals in this tenant, so
> this is a vacuous true negative. The owner check and the `reports/servicePrincipalSignInActivities`
> sign-in check weren't exercised against real data; confirm the sign-in shape once a classic
> Copilot Studio service principal exists in a test tenant.

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
