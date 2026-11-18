Checks MCP tool descriptions for text aimed at the model rather than the reader (tool poisoning), and for tools with
no behavior annotations. Reads every MCP tool in Copilot catalog packages users can reach.

- **Steering text** (Medium): the description or any text in the input schema matches a pattern such as "ignore
  previous instructions", "always call this tool", "do not tell the user", or a request to send credentials. Tune
  the patterns with the `AIGOV.McpSteeringPatterns` setting.
- **No annotations** (Low): none of `readOnlyHint`, `destructiveHint`, `idempotentHint` or `openWorldHint` is set, so
  `MP.AIGOV.1011` and reviewers can't tell what the tool does.

Matches are a prompt for review, not proof of an attack.

Framework: CISA/NSA *Careful Adoption of Agentic AI Services* (standardize tool descriptions, avoid persuasive
language, validate tool selection); NIST 800-53 SI-10.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.
>
> Live attempt Nov 18, 2026: two reachable packages supplied no tool definitions, descriptions or
> annotations. Corrected an unsupported pass over zero parsed tools to an explicit skip.
> There were no available tool descriptions to review; steering-pattern accuracy remains unvalidated.

If any reachable package omits `mcpToolDescription.tools`, this test skips rather than treating missing
metadata as clean descriptions. It does not contact remote MCP servers.

#### Remediation action

Read the flagged tool's full definition. Block the package if the text tries to steer the model. For tools with
no annotations, ask the vendor to add them before you allow the package tenant-wide.

#### Related links

- [Get a Copilot package](https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
