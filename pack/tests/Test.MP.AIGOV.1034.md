Checks the three Microsoft Entra roles that control Copilot and agents: **AI Administrator**, **Agent ID
Administrator** and **Agent Registry Administrator**. All three are labeled privileged in the Entra roles reference.
AI Administrator can change every Copilot setting, approve and publish agents, manage admin consent request
policies, and manage the full lifecycle of agent identities and blueprints.

Reads `GET /roleManagement/directory/roleAssignmentScheduleInstances` for each role with the principal expanded.
Expanded users can omit `userType`; a nested-selection attempt failed during live validation.
The test reads `users/{id}?$select=id,userType` once per affected user, using `User.Read.All`,
and skips if user type still cannot be established. It reports:

- **Permanent active assignment** (`assignmentType` `Assigned`, no `endDateTime`). Microsoft's agent prerequisites
  guidance recommends PIM just-in-time activation for AI Administrator. (High)
- **Guest holder.** (High)
- **Service principal holder.** `MT.1209` covers agent identities with privileged roles; this catches other apps. (High)
- **More distinct holders than `MaxHoldersPerRole`** (default 3, setting `AIGOV.MaxAiAdminRoleHolders`). (Medium)

If the PIM schedule API isn't available (no Entra ID P2), the test falls back to `roleAssignments` and says it
can't tell permanent from activated assignments. AI Reader isn't checked: it can't change settings.

Framework: CISA draft SCuBA agent baseline MS.SI.6.4 (AI admin roles by least privilege); NIST 800-53 AC-6(5), AC-2(7).

> [!NOTE]
> **Validated** Nov 18, 2026 against a live test tenant. Correctly **Failed** (true positive):
> 104 active assignments across the three roles were `Assigned` with no `endDateTime`; each role
> exceeded three holders. Independent eligibility reads returned zero entries. Expanded principals
> omitted `userType`; explicit reads confirmed all 58 distinct users were members. Added explicit
> user-property reads with regression coverage; no actual guest or app assignment was present.

#### Remediation action

Make each AI administration role eligible in Privileged Identity Management with approval and MFA on activation,
remove permanent active assignments, remove guests and apps, and keep the number of holders small.

#### Related links

- [AI Administrator role](https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#ai-administrator)
- [Control access to sensitive roles with PIM (agent prerequisites)](https://learn.microsoft.com/microsoft-365/copilot/agent-essentials/agent-prerequisites#control-access-to-sensitive-roles-with-privileged-identity-management)

<!--- Results --->
%TestResult%
