Checks `GET /identityProtection/riskyAgents` (`graph-rest-beta` — confirmed via the
`Microsoft.Graph.Beta.Identity.SignIns` PowerShell module reference as the documented endpoint for
this resource; no v1.0 equivalent exists today). The `riskyAgent` resource carries `riskState`
(`none`, `confirmedSafe`, `dismissed`, `atRisk`, `confirmedCompromised`, `unknownFutureValue`),
`agentDisplayName`, `riskLevel`, `riskDetail`, `isEnabled`, and `isDeleted`.

"At risk and not yet remediated or dismissed" maps specifically to `riskState eq 'atRisk'`:
`confirmedSafe` and `dismissed` are both post-investigation resolved states. `confirmedCompromised`
agents are listed separately in the result (never silently dropped) but don't drive this finding's
title, since they represent an already-confirmed worse state rather than an unremediated pending
one.

Uses the least-privileged permission confirmed in the Microsoft Graph permissions reference,
`IdentityRiskyAgent.Read.All` — a distinct permission from `IdentityRiskyServicePrincipal.Read.All`,
which covers a different, non-agent resource. The Learn page for this feature currently states
Identity Protection for agents will require a Microsoft Agent 365 license "starting soon" (not
required at the time this test was written).

A 403 is reported as `NotAuthorized` with a message calling out the `IdentityRiskyAgent.Read.All`
permission and the possibility that this tenant has already started requiring a Microsoft Agent 365
license. A 404 is reported separately (also skipped, not a pass) with a message noting the beta
endpoint may not yet be rolled out in this tenant, or Identity Protection for agents may not be
enabled — distinct from an unrelated failure, which still skips with the generic `Error` path.

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed), after the user
> pre-consented the `IdentityRiskyAgent.Read.All` scope. The run correctly **Passed** (true
> negative): `GET /identityProtection/riskyAgents` returned 0 records in this tenant, so neither
> the `atRisk` nor `confirmedCompromised` paths were exercised against real data this round.

#### Remediation action

Investigate each agent identity flagged `atRisk` and either remediate the underlying risk signal or
dismiss it once reviewed. Investigate `confirmedCompromised` agents immediately — they represent a
risk investigation that has already concluded against the agent.

#### Related links

- [Get-MgBetaRiskyAgent](https://learn.microsoft.com/powershell/module/microsoft.graph.beta.identity.signins/get-mgbetariskyagent?view=graph-powershell-beta)
- [Microsoft Graph permissions reference](https://learn.microsoft.com/graph/permissions-reference)

<!--- Results --->
%TestResult%
