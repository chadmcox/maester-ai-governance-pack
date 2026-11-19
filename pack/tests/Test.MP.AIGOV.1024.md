Older Copilot Studio agents with no owner or no recent sign-in are the easiest to forget. They keep their access with nobody responsible for them, which is the kind of identity attackers look for.

#### Remediation action

There's no in-place migration to Agent ID. Retire unused ones instead of recreating them. Give the rest an
owner, then recreate lightly used ones with Agent ID; for busy production agents, Microsoft says to wait for
an automated migration path.

#### Related links

- [Agent identities, service principals and applications](https://learn.microsoft.com/entra/agent-id/agent-service-principals)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1024)

<!--- Results --->
%TestResult%
