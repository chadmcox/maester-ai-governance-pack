Checks who published the agent identity blueprints that other organizations own. Reads the tenant ID and
`GET /servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal` with `appOwnerOrganizationId` and
`verifiedPublisher`. A blueprint principal owned by another tenant (not yours, not Microsoft's) fails when
`verifiedPublisher.verifiedPublisherId` is empty.

`MT.1207` checks whether foreign blueprint principals hold privileged roles; this test checks the publisher.

> [!IMPORTANT]
> The test skips if the derived-type endpoint rejects `verifiedPublisher`, or if no returned principal
> has a populated `verifiedPublisherId`. An empty publisher object alone cannot establish that the API
> supplies this signal. Once at least one populated ID demonstrates availability, foreign principals
> with empty IDs are reported as unverified.

Framework: CISA/NSA *Careful Adoption of Agentic AI Services* (trusted registry of third-party components, verify
origin); NIST 800-53 SR-3, SA-9; AI RMF GOVERN 6.1.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.
>
> Live attempt Nov 18, 2026: selecting `verifiedPublisher` succeeded for all 8 principals, but all
> returned empty publisher IDs. All owner-organization fields were populated; no foreign principal
> was present. The test now skips with an explicit availability reason. Foreign-publisher
> classification is not established by this tenant.

#### Remediation action

Confirm each vendor. Remove blueprint principals you didn't approve, and ask approved vendors to complete
publisher verification.

#### Related links

- [Publisher verification](https://learn.microsoft.com/entra/identity-platform/publisher-verification-overview)

<!--- Results --->
%TestResult%
