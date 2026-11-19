Broad Microsoft Graph write permissions let an agent change users, groups, apps or policies across the whole tenant. If the agent is misused or compromised, the damage reaches far beyond its job, so agents should only get the narrow permissions they need.

#### Remediation action

Replace each permission with a narrower one (for example a `.Selected` or read-only scope), or remove it.
Change permissions on the blueprint principal when every agent from that blueprint has them.

#### Related links

- [Microsoft Graph permissions reference](https://learn.microsoft.com/graph/permissions-reference)
- [Agent identity blueprints](https://learn.microsoft.com/entra/agent-id/agent-blueprint)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1022)

<!--- Results --->
%TestResult%
