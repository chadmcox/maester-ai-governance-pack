> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Failed** (true positive): 5 agent identities and blueprints were flagged for unclear
> names, including a case where the ` (Microsoft Copilot Studio)` suffix was correctly ignored and the
> remaining name ("TestEntraID") still matched the placeholder rule. Confirms the shared naming helper
> (ported from `MP.AIGOV.1006`) works against live Entra Agent ID objects.

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
