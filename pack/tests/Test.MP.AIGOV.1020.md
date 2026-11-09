> [!NOTE]
> **Not yet validated** against a live tenant. Ported from chadmcox/Copilot "Agent and Tools Health Check".

Finds custom or external agents and tools in the Copilot catalog that nobody uses: not blocked, no active
users in the last 30 days, last used more than `StaleDays` ago (or never), and not changed in `StaleDays`.
`StaleDays` defaults to 180, matching Maester's own dormancy tests; 90 is a stricter option.
Microsoft-published packages and App-kind packages (Office add-ins, tabs) aren't checked.

Unused agents and tools keep their permissions and data access. Blocking or removing them shrinks what a
compromise or a mistake can reach.

#### Remediation action

Confirm with the owner that the agent or tool isn't needed, then block it in the Microsoft 365 admin center
(**Agents > All agents**) or remove it.

#### Related links

- [Get a Copilot package](https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/package/copilotpackages-get)

<!--- Results --->
%TestResult%
