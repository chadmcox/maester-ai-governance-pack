Checks the three Microsoft Entra roles that control Copilot and agents: **AI Administrator**, **Agent ID
Administrator** and **Agent Registry Administrator**. All three are labeled privileged in the Entra roles reference.
AI Administrator can change every Copilot setting, approve and publish agents, manage admin consent request
policies, and manage the full lifecycle of agent identities and blueprints.

Reads `GET /roleManagement/directory/roleAssignmentScheduleInstances` for each role with the principal expanded, and
reports:

- **Permanent active assignment** (`assignmentType` `Assigned`, no `endDateTime`). Microsoft's agent prerequisites
  guidance recommends PIM just-in-time activation for AI Administrator. (High)
- **Guest holder.** (High)
- **Service principal holder.** `MT.1209` covers agent identities with privileged roles; this catches other apps. (High)
- **More distinct holders than `MaxHoldersPerRole`** (default 3, setting `AIGOV.MaxAiAdminRoleHolders`). (Medium)

If the PIM schedule API isn't available (no Entra ID P2), the test falls back to `roleAssignments` and says it
can't tell permanent from activated assignments. AI Reader isn't checked: it can't change settings.

Framework: CISA draft SCuBA agent baseline MS.SI.6.4 (AI admin roles by least privilege); NIST 800-53 AC-6(5), AC-2(7).

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.

#### Remediation action

Make each AI administration role eligible in Privileged Identity Management with approval and MFA on activation,
remove permanent active assignments, remove guests and apps, and keep the number of holders small.

#### Related links

- [AI Administrator role](https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#ai-administrator)
- [Control access to sensitive roles with PIM (agent prerequisites)](https://learn.microsoft.com/microsoft-365/copilot/agent-essentials/agent-prerequisites#control-access-to-sensitive-roles-with-privileged-identity-management)

<!--- Results --->
%TestResult%
