> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed), and re-validated
> after adding certificate (`keyCredentials`) support. The run correctly **Passed** (true
> negative): 6 Agent Identity Blueprints were found, 2 of which have an active client secret, and
> neither secret falls within the 30-day warning window. This confirms the
> `applications/microsoft.graph.agentIdentityBlueprint` read and the already-expired exclusion both
> work; a zero-finding result here is the expected negative case, not evidence the check doesn't
> run. No blueprint in this tenant had a `keyCredentials` entry, so the certificate code path ran
> without error but has not been exercised against an actual certificate credential.

Checks whether any Agent Identity Blueprint client secret or certificate credential is still active
but will expire within a configurable warning window (default 30 days). Both `passwordCredentials`
(secrets) and `keyCredentials` (certificates) are checked; the result table includes a `Type`
column distinguishing the two. Maester's own `MT.1208` flags credentials that are
already expired, valid for more than 730 days, exceed a maximum active-secret count, or are
retained alongside a federated identity credential — confirmed by reading its full source — but has
no forward-looking warning before a still-active credential actually expires. This test fills that
gap. An already-expired credential is `MT.1208`'s finding, not this one's; this test explicitly
excludes any `endDateTime` in the past.

#### Remediation action

Rotate the client secret or certificate (or migrate to a federated identity credential) before it
expires, to avoid an unplanned outage when the agent identity loses the ability to authenticate.

#### Related links

- [List agentIdentityBlueprints](https://learn.microsoft.com/graph/api/agentidentityblueprint-list?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
