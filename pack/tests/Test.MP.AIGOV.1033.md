A Copilot connector feeds outside content into Copilot answers for everyone who can search it. If the connector's app isn't one you govern, content from a source you don't control can reach users, or the wrong people can see it.

#### Remediation action

- Remove apps you can't identify, or that belong to a vendor you haven't reviewed, from the
  connection's authorized apps.
- For `limitExceeded`, raise the index quota or narrow what the connector indexes.
- Give each connection a description that says what it holds and who it's for.

#### Related links

- [externalConnection resource type](https://learn.microsoft.com/graph/api/resources/externalconnectors-externalconnection?view=graph-rest-1.0)
- [View connection details](https://learn.microsoft.com/microsoft-365/copilot/connectors/view-details)
- [How this check works](https://github.com/chadmcox/maester-ai-governance-pack/blob/main/docs/how-checks-work.md#mp-aigov-1033)

<!--- Results --->
%TestResult%
