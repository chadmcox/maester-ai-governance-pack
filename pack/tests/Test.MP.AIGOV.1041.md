Checks who published the agent identity blueprints that other organizations own. Reads the tenant ID and
`GET /servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal` with `appOwnerOrganizationId` and
`verifiedPublisher`. A blueprint principal owned by another tenant (not yours, not Microsoft's) fails when
`verifiedPublisher.verifiedPublisherId` is empty.

`MT.1207` checks whether foreign blueprint principals hold privileged roles; this test checks the publisher.

> [!IMPORTANT]
> Confirm in your tenant that `verifiedPublisher` is populated on blueprint principals. If it isn't, every foreign
> blueprint shows as unverified.

Framework: CISA/NSA *Careful Adoption of Agentic AI Services* (trusted registry of third-party components, verify
origin); NIST 800-53 SR-3, SA-9; AI RMF GOVERN 6.1.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.

#### Remediation action

Confirm each vendor. Remove blueprint principals you didn't approve, and ask approved vendors to complete
publisher verification.

#### Related links

- [Publisher verification](https://learn.microsoft.com/entra/identity-platform/publisher-verification-overview)

<!--- Results --->
%TestResult%
