> [!NOTE]
> **Not yet validated** against a live tenant. Ported from chadmcox/Copilot "Agent and Tools Health Check".

Checks names and descriptions on Entra Agent ID objects (`MP.AIGOV.1006` does the same for catalog packages).

- **Unclear name** (agent identities and blueprints): empty, fewer than 4 characters, a placeholder word
  (test, demo, sample, sandbox, temp, tmp, copy, draft, POC, untitled, dummy, delete me, do not use), "new
  agent" or "my bot" and similar, or a trailing number or copy marker such as "Agent 2" or "(1)". The
  " (Microsoft Copilot Studio)" suffix is ignored.
- **Poor description** (blueprints): empty, under 20 characters, or the same as the name.

The word list is chadmcox/Copilot's; Microsoft recommends a naming convention but publishes no list.

#### Remediation action

Rename agents and blueprints so people can tell what they do and who owns them. Describe each blueprint's
purpose, scope and owning team.

#### Related links

- [Agent identity blueprints](https://learn.microsoft.com/entra/agent-id/agent-blueprint)

<!--- Results --->
%TestResult%
