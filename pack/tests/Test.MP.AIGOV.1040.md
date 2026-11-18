Checks the sensitivity label taxonomy that Copilot DLP, Restricted Content Discovery and agent knowledge controls rely
on. Reads `GET /security/dataSecurityAndGovernance/sensitivityLabels` (v1.0) and flattens sublabels.

- **No label scoped to sites or groups** (`applicableTo` without `site` or `unifiedGroup`). (Medium)
- **Two enabled labels with the same full name** (parent/child). (Low)
- **No enabled labels at all.** (Medium)

Whether a default label is set is reported for information only: `isDefault` reflects a label policy, which this API
may not resolve at tenant level. `MT.1173` checks that labels are published.

Framework: CISA draft SCuBA agent baseline MS.SI.6.1, 6.3, 7.2, 7.4; NIST 800-53 AC-16.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.

#### Remediation action

Turn on the *Groups & sites* scope for at least one label, apply container labels to the SharePoint sites and Teams
that Copilot and agents ground on, and rename duplicate labels.

#### Related links

- [List tenant sensitivity labels](https://learn.microsoft.com/graph/api/tenantdatasecurityandgovernance-list-sensitivitylabels?view=graph-rest-1.0)
- [Sensitivity labels for Teams, groups and sites](https://learn.microsoft.com/purview/sensitivity-labels-teams-groups-sites)

<!--- Results --->
%TestResult%
