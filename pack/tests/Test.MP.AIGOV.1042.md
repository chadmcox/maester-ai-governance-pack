With web search on, Copilot sends search queries built from your prompts to Bing. Turning it off, or limiting it to Web mode, keeps work prompts from being sent to Bing.

#### Remediation action

Turn web search off, or limit it to Web mode, in the Microsoft 365 Apps admin center. If you keep it on, add a
Copilot DLP rule that blocks web search for prompts with sensitive information (checked by `MP.AIGOV.1043`).

#### Related links

- [copilotPolicySetting resource](https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/resources/copilotpolicysetting)
- [Manage web search in Copilot](https://learn.microsoft.com/copilot/plan/manage-public-web-access)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1042)

<!--- Results --->
%TestResult%
