# AI Governance

A [Maester Pack](https://maester.dev/docs/packs). Install it with:

```powershell
Install-MtPack chadmcox/maester-ai-governance-pack/pack
```

The installable pack lives in [`pack/`](pack/) (`maester-pack.json`, `tests/`, `helpers/`), not the
repo root. [`unit-tests/`](unit-tests/) holds this repo's own Pester unit tests and is not part of
the installed pack -- see the comment in
[`.github/workflows/test-pack.yml`](.github/workflows/test-pack.yml) for why.

## Tests

| ID | Title | Lifecycle | Status |
| --- | --- | --- | --- |
| MP.AIGOV.1001 | Agent catalog adoption is below a configurable threshold over the D90 report period | Preview | Validated, Graph only |
| MP.AIGOV.1002 | Blocked package has an open pending install or consent request | Preview | Validated, Graph only |
| MP.AIGOV.1003 | Agent is assigned directly to users instead of via a group | Preview | Validated, Graph only |
| MP.AIGOV.1004 | Agent identity, blueprint, or blueprint principal has exactly one sponsor and zero owners | Preview | Validated, Graph only |
| MP.AIGOV.1005 | Classic Copilot Studio service principal has no corresponding Agent ID registration | Preview | Validated, Graph only |
| MP.AIGOV.1006 | Agent display name or description is empty or a placeholder value | Preview | Validated, Graph only |
| MP.AIGOV.1007 | Custom or external package is available or deployed tenant-wide | Preview | Validated, Graph only |
| MP.AIGOV.1008 | MCP server endpoint should not be reachable over plain HTTP | Preview | Validated, Graph only |
| MP.AIGOV.1009 | Agent Identity Blueprint credential should not be nearing expiration | Preview | Validated, Graph only |
| MP.AIGOV.1010 | MCP server should be hosted on an allowlisted domain | Preview | Validated, Graph only |
| MP.AIGOV.1011 | MCP tool with a destructive or open-world effect should not be in a tenant-wide package | Preview | Validated, Graph only |
| MP.AIGOV.1012 | Agent skill should have a clear description, and should not be exposed to Copilot tenant-wide without review | Preview | Validated, Graph only |
| MP.AIGOV.1013 | Enabled spending policy should have a credit ceiling | Preview | Validated, Graph only |
| MP.AIGOV.1014 | Group backing a spending policy should have owners and a description | Preview | Validated, Graph only |
| MP.AIGOV.1015 | Group should not be assigned to more than one enabled spending policy | Preview | Validated, Graph only |

See [`docs/pilot-and-open-questions.md`](docs/pilot-and-open-questions.md) for the full data-source
and skip-condition rationale behind each test, and [`docs/coverage-matrix.md`](docs/coverage-matrix.md)
for how each one maps to existing Maester tests and framework controls.

