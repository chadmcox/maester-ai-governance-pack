Client secrets are passwords stored with the app. They can leak from code, configuration or logs, and anyone who has one can sign in as every agent built from the blueprint. Federated credentials and certificates are much harder to steal.

#### Remediation action

Add a federated identity credential (for example a managed identity) or a certificate to each blueprint, move the
agent's token requests to it, then delete the client secret.

#### Related links

- [Agent identity blueprints](https://learn.microsoft.com/entra/agent-id/identity-platform/agent-blueprint)
- [Microsoft Entra Agent ID best practices](https://learn.microsoft.com/entra/agent-id/best-practices-agent-id)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1035)

<!--- Results --->
%TestResult%
