> [!NOTE]
> **Not yet validated** against a live tenant. Ported from chadmcox/Copilot "Agent and Tools Health Check".

Maester's MT.1223 reports agent identities holding the twelve Microsoft Graph permissions on its
privilege-escalation list. This test covers broad permissions outside that list, on agent identities and
agent identity blueprint principals:

| Severity | Condition |
| --- | --- |
| High | A high-privilege permission: Directory, RoleManagement, Application, AppRoleAssignment, Policy, User, Group, GroupMember, Domain or Organization ReadWrite permissions, or Mail.Send, Mail.ReadWrite, Sites.FullControl.All, Sites.ReadWrite.All, Files.ReadWrite.All, Directory.AccessAsUser.All, full_access_as_app. |
| Medium | Any other tenant-wide write permission (`*.ReadWrite.All`). |

Application permissions (including ones agent identities inherit from their blueprint) and admin-consented
delegated grants are both read. User-consented grants are `MP.AIGOV.1019`. The high-privilege list is
chadmcox/Copilot's, not Microsoft's: Microsoft's guidance is least privilege, with no fixed list.

#### Remediation action

Replace each permission with a narrower one (for example a `.Selected` or read-only scope), or remove it.
Change permissions on the blueprint principal when every agent from that blueprint has them.

#### Related links

- [Microsoft Graph permissions reference](https://learn.microsoft.com/graph/permissions-reference)
- [Agent identity blueprints](https://learn.microsoft.com/entra/agent-id/agent-blueprint)

<!--- Results --->
%TestResult%
