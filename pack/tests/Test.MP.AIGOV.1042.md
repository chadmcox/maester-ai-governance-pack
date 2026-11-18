Reads the *Allow web search in Copilot* policy through `GET /copilot/admin/policySettings/microsoft.copilot.allowwebsearch`
(beta).

| Value | Meaning | Result |
| --- | --- | --- |
| `1` | Web search off for Microsoft 365 Copilot and Copilot Chat | Pass |
| `2` | Off in Work mode, on in Web mode and Copilot Chat | Pass, with a note |
| `0` or not set | On for everyone (the commercial default) | Fail (Low) |

Web search data is handled under Bing consumer terms. The API supports **delegated permissions only**, so the test
skips in an app-only run. It returns 502 when a tenant has too many group-level Copilot policies; the test skips then.

Framework: CISA draft SCuBA agent baseline MS.SI.10.3; NIST 800-53 AC-4.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.

#### Remediation action

Turn web search off, or limit it to Web mode, in the Microsoft 365 Apps admin center. If you keep it on, add a
Copilot DLP rule that blocks web search for prompts with sensitive information (checked by `MP.AIGOV.1043`).

#### Related links

- [copilotPolicySetting resource](https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/resources/copilotpolicysetting)
- [Manage web search in Copilot](https://learn.microsoft.com/copilot/plan/manage-public-web-access)

<!--- Results --->
%TestResult%
