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
>
> Seeded attempt Nov 18, 2026: a custom app declaring two MCP tools was uploaded in the Teams admin center, but it
> did not appear in the Copilot package catalog within an hour, so it couldn't be evaluated. A source review found
> that a tool with both steering text and no annotations was reported for steering text only; it now lists both.
>
> **Seeded rerun** Nov 19, 2026: the custom app (a test object created for this run) reached the catalog. The test
> **Failed** (Medium) as expected: 1 tool with steering text, 0 tools without annotations. The steering branch is
> validated live; the no-annotations branch is still unit-tested only.

Packages that omit `mcpToolDescription.tools` are listed in the result; tools from the other packages are
still checked, and any steering text or missing annotation fails the test. With no findings but some packages
missing definitions, the test skips as a partial check instead of passing, because missing metadata isn't a
clean description. It does not contact remote MCP servers.

Rerun Nov 18, 2026 (commit `783b36e`): still **Skipped**. Two reachable packages, zero tool definitions; an
independent read of the raw package definitions agreed. The skip reason now names those packages.

#### Remediation action

Read the flagged tool's full definition. Block the package if the text tries to steer the model. For tools with
no annotations, ask the vendor to add them before you allow the package tenant-wide.

#### Related links

- [Get a Copilot package](https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
