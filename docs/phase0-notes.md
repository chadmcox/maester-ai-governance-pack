# Phase 0 notes — Maester AI-governance pack

All claims below are verified against `maester365/maester` at commit
`616559854634e5150dbde69850c4224191635bb1` (shallow clone, main branch) unless an
external URL is cited. File paths are relative to the repo root.

## 1. How Maester actually distributes third-party tests

There is **no separate "Maester Pack" product name** — the real mechanism is the
**Packs system**, which is part of Maester core (3.0+). It is real, shipping, and
exactly what we need. Two kinds of packs exist:

- **Built-in packs** — ship inside `maester365/maester` itself (e.g.
  `packs/zero-trust-assessment/maester-pack.json`). Their test IDs have no prefix
  (bare `<Code>.<n>`, e.g. `ZTA.21770`). Not our path — we are not merging into
  Maester core.
- **External packs** — any public GitHub repo with a tagged release, installed by
  the *consumer* running `Install-MtPack <owner>/<repo>[/subfolder][@ref]`
  (`powershell/public/packs/Install-MtPack.ps1`). This is our path.

Key mechanics of `Install-MtPack`:

- Reads `maester-pack.json` from the target repo/ref (schema documented in full in
  `website/docs/packs/writing-a-pack.md`).
- Enforces a **72-hour release cooldown** by default (`PackPolicy.CooldownHours`),
  bypassable with `-IncludeRecent`.
- Classifies install risk **Low / Medium / High** (driven by what the manifest's
  `Uses` block declares — Graph scopes, tenant-write capability, network egress,
  required PowerShell modules) and requires `-AcceptRisk` for unattended
  (`-NonInteractive`) installs above Low.
- Writes two files into the **consumer's** project, not ours:
  `maester-packs.lock.json` (pins exact commit SHA + content digest + the test ID
  list + risk level + required modules) and `maester-config.json` (adds the pack
  under a `Packs` list so `Invoke-Maester` picks it up on later runs).
- `Test-MtPack ./local-folder` (`powershell/public/packs/Test-MtPack.ps1`) runs the
  identical manifest/ID/module validation `Install-MtPack` would, without
  installing — this is what our pack repo's own CI should run on every PR.
- Publishing to `packs.maester.cloud/publish` is **entirely optional** — it only
  adds discoverability in Maester's pack catalog UI. `Install-MtPack
  chadmcox/maester-ai-governance-pack` works against our repo the moment it has a
  release, whether or not we ever publish there.

**Recommendation:** install method for users is `Install-MtPack
chadmcox/maester-ai-governance-pack`. No submission to Maester core, no PR against
`maester365/maester` is needed or wanted.

**Test ID scheme (reserved prefix list from `powershell/assets/MaesterTestSchema.psd1`):**
`MT.`, `CISA.`, `CIS.`, `EIDSCA.`, `ORCA.`, `AD-`, `AZDO.`, `MT1060.`, `ASD.`, `MP.`,
`ZTA.` are reserved for Maester-owned suites. External packs must use `MP.<Code>.<n>`.
`Code` = 1–3 dot-separated parts, each 2–10 letters/digits starting with a letter,
and must not collide (including by prefix) with any other installed pack's code. No
central registry reservation is mandatory; **`AIGOV`** is confirmed unclaimed as of
this run — checked the live `packs.maester.cloud` public index directly; no listed
pack uses that code or a `*.aigov` slug (existing packs use publisher-prefixed
slugs like `rks.ia`, `jl.cisw11int.l1`, `clt.ua`, worth knowing if a similar prefix
is wanted later, but not required).

`New-MtPack -Path ./x -Id chadmcox.ai-governance -Code AIGOV` scaffolds the correct
folder layout: `maester-pack.json`, `tests/suite.json`, `Test.MP.AIGOV.<n>.ps1` +
matching `.md`, `helpers/`.

## 2. Maester test conventions

Source: `powershell/assets/MaesterTestSchema.psd1` (full schema), confirmed by
`powershell/tests/general/NativeTestAttributes.Tests.ps1` and
`powershell/internal/engine/Get-MtSuiteFramework.ps1`.

- **`Severity`** — exactly 5 values: `Critical`, `High`, `Medium`, `Low`, `Info`.
- **`Control`** — `string[]`, pattern `^[a-z0-9][a-z0-9.\-]*:[^\s,]+$`, i.e.
  `<framework-key>:<requirement-id>`. Multiple entries allowed (primary benchmark
  first, secondary cross-references after).
- **Framework-key validation — important nuance.** Only suites `ASD`, `CIS`, `CISA`
  declare a catalog of valid requirement IDs, keyed by `cis-github`, `cis-m365`,
  `cisa-scuba`, `essential-eight`, `ism`
  (`powershell/internal/engine/Get-MtSuiteFramework.ps1` — this is an enforced,
  closed list; a test inside one of those suites must reference a requirement ID
  that really exists in `tests/cis/frameworks/cis-m365.json` /
  `tests/cisa/frameworks/cisa-scuba.json` / `tests/asd/frameworks/*.json` or CI
  fails). Separately, **`nist-800-53-r5:*`** references are validated **repo-wide**
  (any suite) against `powershell/assets/MaesterNistControls.json` (>900 real
  control IDs, confirmed via a test assertion). **Checked both catalogs directly
  this run: neither `cis-m365.json` nor `cisa-scuba.json` contains any
  AI/Copilot/agent-specific requirement today** (zero matches for `ai|copilot|agent`
  as a word). So our pack cannot cite "Direct requirement" against CIS M365 or
  CISA SCuBA for anything AI-specific — at best "Supporting alignment" against
  their general identity/app-governance/CA requirements.
  No catalog exists for `nist-csf` or `nist-ai-rmf` keys — Maester will accept the
  pattern but never verifies them. We must verify those against the primary NIST
  documents ourselves (done in the coverage matrix).
- **`Permission`** format `<Service>:<Kind>:<Name>` — "recorded, not enforced":
  Maester does not check the caller's actual Graph roles at runtime; this is
  documentation for the admin granting consent.
- **`Lifecycle`** — `Preview` tests are excluded from a default run unless
  `-IncludePreview`, a matching `-Tag`, or the literal `-TestId` is passed.
  Interestingly, **Maester's own brand-new MT.12xx agent-identity tests are all
  tagged `Preview`** themselves (confirmed directly in `Test.MT.1206.ps1`,
  `Test.MT.1211.ps1`, etc.) — i.e. this entire area is still experimental even
  inside Maester core. We should follow the same convention for new pack tests.
- **Reserved parameter names:** a test may not declare a parameter named
  `Instance` or prefixed `Mt` (engine-reserved).

**Skip pattern** (`powershell/public/run/Add-MtTestResultDetail.ps1`):
`-SkippedBecause` is a fixed `ValidateSet` with ~30 values (`NotConnectedGraph`,
`NotLicensedEntraIDP2`, `NotAuthorized`, `LimitedPermissions`, `Error`, `Custom`,
etc.) — **no agent/MCP/Power-Platform-specific reason exists today.** Every
MT.12xx test actually in the repo uses `NotAuthorized` (403/forbidden/authorization
text match) or generic `Error` with `-SkippedError`. The copilot-studio MT.111x–112x
tests instead use `SkippedBecause Custom` with a shared helper
`Get-MtAIAgentSkippedReason -TestId 'MT.xxxx'` for a consistent message. **We will
follow the same two patterns**: `NotAuthorized`/`Error` for raw Graph calls,
`Custom` with a shared message helper for anything needing extra tenant-specific
skip text (e.g. "Power Platform admin API not reachable").

## 3. Per-surface read API and least-privileged permission

| Surface | API | Version | Permission (least privilege) | Notes |
|---|---|---|---|---|
| 1. Agents (Copilot/Copilot Studio/Agent 365 catalog) | Two distinct data sources, confirmed this run — do not conflate them: (a) **Copilot Studio agent/topic metadata** (`AgentToolsDetails`, `RawAgentInfo`, `AIAgentName`/`AgentStatus`/`LastModifiedTime`), read via `Get-MtAIAgentInfo`, which MT.1113–1122 all call — **this is Dataverse-backed, not Graph** (confirmed by reading the helper call site directly in `Test.MT.1117.ps1`/`Test.MT.1118.ps1`). (b) **Package Management API** (`copilot/admin/catalog/packages`) — this one genuinely is Graph v1.0, confirmed via Microsoft Learn and a live 403 against the test tenant, but is gated behind a Microsoft Agent 365 license. | (a) Dataverse via Copilot Studio connection; (b) Graph v1.0, license-gated | (a) Power Platform/Dataverse connection, not a Graph scope; (b) `CopilotPackages.Read.All`, + Agent 365 license | Earlier draft of this note incorrectly called the whole surface "Graph v1.0" — corrected after review feedback confirmed `Get-MtAIAgentInfo` is Dataverse. New pilot findings against the Package API ((b)) are genuinely Graph-only; anything extending MT.1117/1118/1121-style Topic logic ((a)) is not. |
| 2. Agent identities / blueprints (Entra Agent ID) | Graph v1.0 `servicePrincipals/microsoft.graph.agentIdentity`, `servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal`, `applications/microsoft.graph.agentIdentityBlueprint` (+ `/inheritablePermissions` sub-resource); sign-in activity via Graph **beta** `reports/servicePrincipalSignInActivities?$filter=appId eq '...'` | v1.0 for objects, beta for sign-in reports | `Application.Read.All`, `AuditLog.Read.All` (for sign-in activity) | Confirmed directly from `Test.MT.1200/1203/1206.ps1` source. This whole area (MT.1200–1225) is `Preview` lifecycle in Maester itself. |
| 3. Tools/MCP | Attempted a live check this run: `GET /v1.0/copilot/admin/catalog/packages?$expand=packageElementDetail` against the test tenant returned `403 Forbidden` — confirmed via Microsoft Learn this is the Agent 365 license gate, not a consent/scope problem (`CopilotPackages.Read.All`, GA at v1.0). Documented `packageElementDetail.elementType` example values are `CustomEngineCopilot`/`DeclarativeAgent`/`Bot` — **no confirmed `agentConnectors`/MCP element type in the published schema**. Separately, Microsoft's "Build plugins for Copilot Cowork" packaging guide describes an `agentConnectors` section in a Cowork plugin manifest (remote connector/MCP tool descriptions), but that is a manifest-file concept, not a documented queryable Graph property. Beyond this, MT.1120 already covers MCP tool review via pattern-matching inside the (Dataverse) agent tool metadata; full MCP-server inventory otherwise still needs Defender/XDR Advanced Hunting (MT.1077-1079 territory, MDA App Governance + MDI). | Package API: v1.0, license-gated; else Defender XDR | `CopilotPackages.Read.All` + Agent 365 license; or Defender Advanced Hunting roles | **Not independently testable via Graph alone today.** Needs a license-enabled test tenant to confirm whether `agentConnectors`/MCP element types are actually queryable before any new finding is designed against this API. |
| 4. Connectors (Power Platform / Copilot Studio connectors + connections) | Power Platform API: `GET https://api.powerplatform.com/connectivity/environments/{environmentId}/connectors?$filter=...&api-version=2024-10-01` (list connectors per environment); DLP via `Get-AdminDlpPolicy` (PowerShell module) which wraps the BAP admin API, and the newer `GET https://api.powerplatform.com/governance/ruleBasedPolicies?api-version=2024-10-01` (rule-based/tenant governance policies, a different and newer policy object than classic DLP) | Power Platform API 2024-10-01 | Power Platform admin role (Global/Power Platform admin), or an Entra app with the Power Platform API's `.default` application permission | Verified both endpoints exist via Microsoft Learn (`learn.microsoft.com/en-us/rest/api/power-platform/connectivity/connectors/list-connectors`, `.../governance/rule-based-policies/list-rule-based-policies`). Classic DLP policy read/write is still cmdlet-only (`Microsoft.PowerApps.Administration.PowerShell`), not yet a documented plain REST verb in the same API family — note this distinction for pack authors. |
| 5. Skills | **Corrected this run — Skills ≠ Copilot Studio Topics.** Microsoft's Copilot Studio "Skills overview" page describes Generative (Markdown `SKILL.md`) vs. Topic skills, but the *Cowork plugin* packaging model (verified via `learn.microsoft.com/copilot/cowork/cowork-plugin-development`) is the concrete, current implementation: a plugin manifest has an `agentSkills` section (SKILL.md files) and optionally an `agentConnectors` section (MCP/remote-connector tools) — these are packaging-time, not confirmed as live-queryable `elementType` values via the Package Management API (see surface 3 row — same 403/license gate applies, and the documented enum only shows `Bot`/`DeclarativeAgent`/`CustomEngineCopilot`). Copilot Studio's own **Topics** (what MT.1117/MT.1121/MT.1118 actually read, via `Get-MtAIAgentInfo` — Dataverse) are a related but distinct, older object; findings against Topics should be labeled "Topic hygiene," not "Skills." | Package API: v1.0, license-gated, unconfirmed schema; Topics: Dataverse via Copilot Studio | `CopilotPackages.Read.All` + Agent 365 license (Skills); Dataverse/Power Platform connection (Topics) | **Skills (SKILL.md packages): not independently testable with current evidence** — needs a license-enabled tenant to confirm the real `elementType` taxonomy before any finding is designed. **Topic hygiene: testable today**, same Dataverse surface as MT.1117/1121/1118, but is not Graph-only. |
| 6. Billing / spending policies | Microsoft Graph **beta** `/copilot/costManagement` surface — `getTenantCreditBalance`, `spendingPolicies` (list/get/create/update/delete), `spendingPolicies/{id}/microsoft.graph.selectedGroupsSpendingPolicy/assignedGroups`, per-user `costManagement/usageReports/userUsageDetails` | beta only (explicitly marked "APIs under /beta are subject to change... not supported in production" by Microsoft) | Graph permission is a new Copilot-cost-management-specific scope; exact name not yet confirmed this run (follow up before writing code) | Confirmed the surface is real and readable via `learn.microsoft.com/.../api/admin-settings/cost-management/overview` (fetched this run). **Include billing findings** per the user's "only if readable via Graph" instruction — it is, but beta-only, so tests must tolerate schema churn and should stay `Preview` lifecycle. |

**Not testable today (no API at all found):** Generative/Markdown Copilot Studio
skill packages (surface 5, partially); full MCP-server inventory independent of
Defender XDR (surface 3, partially).

## 4. Inactivity threshold

Claimed 180-day default **confirmed directly in source, twice, independently**:

- `tests/maester/copilot-studio/Test.MT.1117.ps1` line 49: `$thresholdDays = 180`
  (agent dormancy).
- `tests/maester/entra/Test.MT.1206.ps1`: `[int]$MaxInactiveDays = 180` parameter
  default (agent-identity sign-in inactivity).

Our pack's own inactivity-threshold tests should default to **180 days** (matching
Maester's own convention exactly) and expose a `maester-config.json`-configurable
override, documenting **90 days** as the stricter option the user requested.

## 5. Framework sources used

- **CISA SCuBA** — Maester's own `tests/cisa/frameworks/cisa-scuba.json` is the
  primary source for any `cisa-scuba:MS.*` ID we reuse; confirmed it has zero
  AI/Copilot/agent terms today.
- **CIS M365 Benchmark** — Maester's own `tests/cis/frameworks/cis-m365.json` is
  the primary source for any `cis-m365:*` ID; also zero AI/Copilot/agent terms
  today. (Benchmark version number embedded in that file was not separately
  re-extracted this run — do before final publication.)
- **NIST SP 800-53 Rev 5** — `powershell/assets/MaesterNistControls.json`
  (Maester's own verified catalog, >900 IDs) is the primary source; every
  `nist-800-53-r5:*` ID proposed in the coverage matrix should be checked against
  that file before it ships (not yet done for every proposed new ID — flagged per
  row).
- **NIST AI RMF 1.0** — verified directly against `airc.nist.gov/airmf-resources/airmf/5-sec-core/`
  (primary NIST source, fetched this run) for the Govern/Map/Measure/Manage
  function structure, cross-checked at the category level against two independent
  secondary summaries (stigviewer.com, gage.academy) for exact subcategory wording.
  No Maester-internal catalog exists for this key — pattern-valid only, unverified
  by Maester's own CI.
- **NIST CSF 2.0** — dropped per your decision; not used anywhere in the final
  matrix or pilot.
- **CIS Controls v8.1 Safeguards + CISA agentic-AI risk categories** — added per
  your decision, sourced from `chadmcox/Copilot`'s own
  `Agent and Tools Health Check/Cowork/plugin/skills/agent-tools-health/references/guidance.md`,
  which itself states the safeguard/category mapping is "this repo's judgment, not
  something CIS or CISA published." Carried into the matrix tagged **Supporting
  alignment only**, never Direct requirement, with that same caveat repeated.

## 6. Licensing note

`chadmcox/Copilot` has no LICENSE file. No code was copied from it into any
deliverable this run; only logic/field-name inspiration is reused (e.g. the
"blocked + pending request" and "Copilot adoption %" concepts already implemented
there independently in PowerShell against different Graph calls). Once the user
adds an MIT license there, these can be ported more directly.
