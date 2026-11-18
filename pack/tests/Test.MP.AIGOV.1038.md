Detects MCP tools that changed after you approved them (a "rug pull"). Reads every MCP tool in Copilot catalog
packages users can reach, fingerprints each tool's name, description, input schema and annotations with SHA-256, and
compares them with the baseline in the `AIGOV.McpToolBaseline` setting.

- **Changed:** a baseline tool whose fingerprint differs. (Medium)
- **New:** a reachable tool that isn't in the baseline. (Medium)
- Removed tools are listed for information only.

With no baseline set, the test skips and prints the current fingerprints as JSON. Review those tools, then add the
approved entries to `maester-config.json`:

```json
{
  "GlobalSettings": {
    "AIGOV.McpToolBaseline": [
      { "PackageId": "<package id>", "ToolName": "search", "Fingerprint": "<sha256>" }
    ]
  }
}
```

Framework: CISA/NSA *Careful Adoption of Agentic AI Services* (allow-list tools and versions, verify origin and
currency); CIS Controls v8.1 MCP Companion Guide; NIST 800-53 CM-2, CM-3.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.

#### Remediation action

Review each changed or new tool's definition. If you accept it, update its fingerprint in the baseline. If you
don't, block the package in the Microsoft 365 admin center until the vendor explains the change.

#### Related links

- [Get a Copilot package](https://learn.microsoft.com/graph/api/copilotadmin-get-package?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
