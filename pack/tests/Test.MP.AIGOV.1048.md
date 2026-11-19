Models differ in safety, capability, cost and support life. Allowing only approved models keeps teams off retired, unreviewed or unsuitable models, and makes it clear which models your controls were tested with.

#### Remediation action

Remove or replace deployments that use unapproved models, or add the model to `AIGOV.ApprovedModels` after
review. To block new ones, assign Azure Policy built-ins for allowed models (see the AI-1 policy mapping in
MCSB v2).

#### Related links

- [MCSB v2: Artificial Intelligence Security (AI-1)](https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-artificial-intelligence-security)
- [Deployments - List (Azure AI Services account management)](https://learn.microsoft.com/rest/api/aiservices/accountmanagement/deployments/list)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1048)

<!--- Results --->
%TestResult%
