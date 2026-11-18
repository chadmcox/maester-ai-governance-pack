Checks the Azure resources behind Azure OpenAI and Microsoft Foundry. Reads Azure Resource Graph for
`Microsoft.CognitiveServices/accounts` of kind `OpenAI` or `AIServices`, and each of those subscriptions' Defender for
Cloud AI plan (`Microsoft.Security/pricings/AI`). An account fails (Medium) when:

- `disableLocalAuth` isn't `true` (API keys work, with no Entra identity or Conditional Access);
- `publicNetworkAccess` is `Enabled` and `networkAcls.defaultAction` isn't `Deny`;
- the subscription's Defender for AI Services plan isn't `Standard`.

No accounts is a pass. This is the pack's only Azure check; Azure Policy may already enforce these settings.

Framework: NIST 800-53 IA-2, SC-7, SI-4.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.
>
> Live attempt Nov 18, 2026 returned no matching AI accounts, and an independent subscription
> enumeration returned zero accessible subscriptions. The empty-inventory pass is not proof of
> account hardening or Defender coverage. No subscription was available for a pricing GET;
> `disableLocalAuth`, `publicNetworkAccess`, and `pricingTier` remain unvalidated.

#### Remediation action

Set `disableLocalAuth` to true and move callers to Entra ID (managed identities), restrict network access with
private endpoints or network rules, and turn on Defender for AI Services for the subscription.

#### Related links

- [Disable local authentication in Azure AI services](https://learn.microsoft.com/azure/ai-services/disable-local-auth)
- [AI threat protection in Defender for Cloud](https://learn.microsoft.com/azure/defender-for-cloud/ai-threat-protection)

<!--- Results --->
%TestResult%
