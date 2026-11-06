Checks whether any enabled Conditional Access policy targets agent identities. Reads `GET
/identity/conditionalAccess/policies` (`graph-rest-beta` — the properties below do not exist on the
v1.0 `conditionalAccessClientApplications` or `conditionalAccessConditionSet` resources, confirmed
by comparing the beta and v1.0 schema reference pages). A policy "targets agent identities" when its
`conditions.clientApplications.includeAgentIdServicePrincipals` is non-empty, its
`conditions.clientApplications.agentIdServicePrincipalFilter.rule` is set, or its
`conditions.agentIdRiskLevels` is non-empty.

Reports three independent outcomes:

- **Full pass**: at least one enabled policy targets agent identities dynamically, via
  `agentIdServicePrincipalFilter` or `agentIdRiskLevels`, so current and future agent identities are
  automatically covered.
- **Partial coverage (Medium)**: enabled policies target agent identities, but only by a static
  `includeAgentIdServicePrincipals` ID list — no filter or risk condition. There is no "All"
  sentinel value for this property (confirmed against the `conditionalAccessClientApplications` beta
  schema reference), so a newly created agent identity is not automatically covered until an admin
  adds its ID to the policy.
- **No coverage (High)**: either no policy targets agent identities at all, or agent-targeting
  policies exist but every one has `state` `disabled` or `enabledForReportingButNotEnforced`
  (report-only), so none is actually enforced.

This intentionally does not duplicate `MT.1181` ("Conditional Access policy is present that blocks
high agent risk sign-ins"), confirmed by reading its source
(`Test-MtCaAgentRiskBlockPolicy.ps1`): `MT.1181` checks the narrow case of
`conditions.agentIdRiskLevels` containing `high` **and** `grantControls.builtInControls` containing
`block` on an enabled policy. This test is broader and upstream of that one — it flags a tenant with
no agent-identity Conditional Access coverage at all, regardless of control type. A tenant where
`MT.1181` passes will also pass this test's condition (a), since a block-on-high-risk policy also
targets agent identities via `agentIdRiskLevels`. But a tenant that targets agent identities only
with a non-block control, or only in report-only mode, is still flagged here even though it falls
outside `MT.1181`'s narrower scope.

> [!NOTE]
> **Validated** 2026-11-06 against a real Microsoft 365 test tenant (F7-licensed). The run
> correctly **Passed** (true negative): of 57 total Conditional Access policies, 6 enabled
> policies already target agent identities, so condition (a) does not apply. This run also
> caught and fixed a wrong endpoint path (`identity/conditionalAccessPolicies` instead of the
> correct `identity/conditionalAccess/policies`), confirming the request is well-formed against
> real data, not just schema documentation.

#### Remediation action

Create at least one enabled Conditional Access policy that targets agent identities dynamically
(via `agentIdServicePrincipalFilter` or an agent risk condition), rather than relying solely on a
static `includeAgentIdServicePrincipals` ID list, and move any existing report-only agent-targeting
policy to enabled once validated.

#### Related links

- [Target agent identities in Microsoft Entra Conditional Access policies](https://learn.microsoft.com/entra/identity/conditional-access/howto-target-agent-identities)
- [conditionalAccessClientApplications resource type](https://learn.microsoft.com/graph/api/resources/conditionalaccessclientapplications?view=graph-rest-beta)
- [conditionalAccessConditionSet resource type](https://learn.microsoft.com/graph/api/resources/conditionalaccessconditionset?view=graph-rest-beta)

<!--- Results --->
%TestResult%
