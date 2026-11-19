Copilot decides when to use a skill from its description. A vague description makes the skill run at the wrong time or not at all, and a skill exposed to everyone without review can change how Copilot behaves across the whole organization.

#### Remediation action

For a weak description, rewrite `frontmatter.description` to clearly state when the skill should
trigger. For a tenant-wide exposed skill, scope the package's availability and deployment to a
specific group, or confirm with the publisher that broad exposure is intentional and reviewed.

#### Related links

- [Get Copilot package](https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1012)

<!--- Results --->
%TestResult%
