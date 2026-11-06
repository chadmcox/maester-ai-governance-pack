Checks whether an agent skill (the `SKILL.md`-style packaging described by Microsoft's Copilot
Cowork plugin guide, confirmed as a real `elementTypes` value: `AgentSkills`) has a weak frontmatter
description, or is exposed to Copilot inside a package that's available or deployed tenant-wide. The
skill definition comes from the per-package detail call (`GET
/copilot/admin/catalog/packages/{id}`), specifically the `elementDetails` entry with `elementType`
`AgentSkills`, whose `elements[].definition` (a JSON string) contains `expose_skill_to_copilot`
(boolean) and `frontmatter.{name,description}`.

A skill is flagged if either condition holds:

- Its `frontmatter.description` is empty or shorter than a configurable `-MinDescriptionLength`
  (default 40 characters). Copilot uses this text to decide when to invoke the skill, so a missing
  or vague one risks it firing on the wrong request, or never firing at all.
- `expose_skill_to_copilot` is `true` **and** the package is available or deployed tenant-wide (the
  same signal `MP.AIGOV.1007` and `MP.AIGOV.1011` use). A skill explicitly exposed to Copilot,
  reachable by everyone by default, should get the same deliberate, scoped rollout review as any
  other tenant-wide tool.

Detail-call and definition-parse failures are counted the same way as `MP.AIGOV.1008`/
`MP.AIGOV.1010`/`MP.AIGOV.1011`: a partial failure is noted in the result, and a total failure skips
with `Error` instead of reporting a false pass.

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed). The run
> correctly **Failed** (true positive) against real data: 32 packages had an agent skill element,
> confirming the `AgentSkills` `elementDetails` schema (`folder`, `expose_skill_to_copilot`,
> `frontmatter.{name,description}`) against a real skill ("Moody's Credit MCP"'s "earnings-brief"
> skill).

#### Remediation action

For a weak description, rewrite `frontmatter.description` to clearly state when the skill should
trigger. For a tenant-wide exposed skill, scope the package's availability and deployment to a
specific group, or confirm with the publisher that broad exposure is intentional and reviewed.

#### Related links

- [Get Copilot package](https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
