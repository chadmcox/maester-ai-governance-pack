> [!NOTE]
> **Validated** 2026-11-09 against a real Microsoft 365 test tenant, via an actual `Invoke-Maester` run.
> The run correctly **Failed** (true positive): one custom agent ("Vani") was never used and hadn't been
> modified in over 180 days. The package-detail `activeUsers` and `lastUsedDateTime` properties read and
> typed as expected.

> **Revised** 2026-11-11: now checks only packages people can reach (not blocked, and `availableTo` not
> allowedForNone). "Vani" from the validation run was available to no one, so there was nothing to block;
> it no longer fires. Re-validation pending.

Finds custom or external agents and tools in the Copilot catalog that nobody uses: people can reach them, no active
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
