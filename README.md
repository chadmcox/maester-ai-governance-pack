# AI Governance

A [Maester Pack](https://maester.dev/docs/packs). Install it with:

```powershell
Install-MtPack chadmcox/maester-ai-governance-pack
```

## Tests

| ID | Title | Lifecycle | Status |
| --- | --- | --- | --- |
| MP.AIGOV.1001 | Agent catalog adoption is below a configurable threshold over the D90 report period | Preview | NOT VALIDATED (needs an Agent 365-licensed tenant) |
| MP.AIGOV.1002 | Blocked package has an open pending install or consent request | Preview | NOT VALIDATED (needs an Agent 365-licensed tenant) |
| MP.AIGOV.1003 | Agent is assigned directly to users instead of via a group | Preview | NOT VALIDATED (needs an Agent 365-licensed tenant) |
| MP.AIGOV.1004 | Agent identity, blueprint, or blueprint principal has exactly one sponsor and zero owners | Preview | Built, Graph only |
| MP.AIGOV.1005 | Classic Copilot Studio service principal has no corresponding Agent ID registration | Preview | Built, Graph only |
| MP.AIGOV.1006 | Agent display name or description is empty or a placeholder value | Preview | NOT VALIDATED (needs an Agent 365-licensed tenant) |
| MP.AIGOV.1007 | Custom or external package is available or deployed tenant-wide | Preview | NOT VALIDATED (needs an Agent 365-licensed tenant) |

See [`docs/pilot-and-open-questions.md`](docs/pilot-and-open-questions.md) for the full data-source
and skip-condition rationale behind each test, and [`docs/coverage-matrix.md`](docs/coverage-matrix.md)
for how each one maps to existing Maester tests and framework controls.

