Checks agent identity blueprints for client secrets. Reads `GET /applications/microsoft.graph.agentIdentityBlueprint`
with `passwordCredentials` and `keyCredentials`, then each flagged blueprint's `federatedIdentityCredentials`.

A blueprint fails when it has at least one client secret that hasn't expired, whether or not it also has a
certificate or a federated credential. Already-expired secrets are left to `MT.1208`.

This is broader than `MT.1208`, which flags a secret only when it sits beside a federated credential, is expired,
is too long-lived, or is one of too many. It is your coverage matrix row **P2**.

Framework: CISA draft SCuBA agent baseline MS.SI.2.1 (SHALL use federated credentials or certificates, not client
secrets); CISA/NSA *Careful Adoption of Agentic AI Services* (replace static, long-lived secrets); NIST 800-53 IA-5.

> [!NOTE]
> **Validated** Nov 18, 2026 against a live test tenant. Correctly **Failed** (true positive):
> 2 of 6 blueprints had an active password credential. Independent reads confirmed that
> `applications/{id}/federatedIdentityCredentials` works for this derived type; two blueprints
> returned one federated credential each. No certificate credentials were present.

#### Remediation action

Add a federated identity credential (for example a managed identity) or a certificate to each blueprint, move the
agent's token requests to it, then delete the client secret.

#### Related links

- [Agent identity blueprints](https://learn.microsoft.com/entra/agent-id/identity-platform/agent-blueprint)
- [Microsoft Entra Agent ID best practices](https://learn.microsoft.com/entra/agent-id/best-practices-agent-id)

<!--- Results --->
%TestResult%
