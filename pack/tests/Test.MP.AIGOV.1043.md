Checks what your enforced Copilot DLP policies protect. Reads DLP policies and rules with Security & Compliance
PowerShell (`Get-MtExo -Request DlpCompliancePolicy` and `DlpComplianceRule`). Only policies that target the Microsoft 365
Copilot location, are enabled, in `Mode` `Enable` and not in simulation count, and only their rules that aren't
disabled.

| Protection | How a rule is recognized | Severity if missing |
| --- | --- | --- |
| Block prompts with sensitive info types | SIT condition + `RestrictAccess` `ExcludeContentProcessing` = `Block` | Medium |
| Block labeled files and email | Sensitivity label condition + the same action | Medium |
| Block web search for sensitive prompts | `RestrictWebGrounding` = `true` | Low |
| Exclude external email from grounding (preview) | `FromScope` `NotInOrganization` + the processing block | Low |

When no enforced Copilot DLP policy exists the test skips: `MT.1175` and CIS M365 3.2.3 report that. Rule conditions
are matched from the rule's text, so confirm a *Missing* row in the Purview portal. Blocking labeled content needs
Microsoft 365 E5-level Purview; blocking prompts is available to all Copilot users.

Framework: CISA draft SCuBA agent baseline MS.SI.10.2, 10.3, 10.5, 10.6; NIST 800-53 AC-4.

> [!NOTE]
> **Not yet validated** against a live tenant. Unit-tested only (Pester, mocked data). Run it against your
> tenant and check the result before relying on it.

#### Remediation action

Add the missing rules to an enforced Copilot DLP policy in the Microsoft Purview portal, test them in simulation,
then turn them on.

#### Related links

- [DLP for Microsoft 365 Copilot, Copilot Chat and Cowork](https://learn.microsoft.com/purview/dlp-microsoft365-copilot-location-learn-about)
- [New-DlpComplianceRule](https://learn.microsoft.com/powershell/module/exchangepowershell/new-dlpcompliancerule)

<!--- Results --->
%TestResult%
