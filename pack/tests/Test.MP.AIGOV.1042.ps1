function Test-MPAIGOV1042 {
    <#
    .SYNOPSIS
    Reports whether Microsoft 365 Copilot and Copilot Chat can use public web search.
    .DESCRIPTION
    Reads GET /copilot/admin/policySettings/microsoft.copilot.allowwebsearch (beta). The value comes
    from the tenant-level "Allow web search in Copilot" cloud policy:

    - '1': web search is off for Microsoft 365 Copilot and Copilot Chat. Pass.
    - '2': web search is off in Work mode and on in Web mode and Copilot Chat. Pass, with a note.
    - '0', or no tenant-level policy: web search is on for everyone (the default in commercial
      tenants). Fail (Low).

    Web search data is handled under Bing consumer terms, outside Microsoft 365 data processing terms.
    CISA's draft SCuBA agent baseline (MS.SI.10.3) says Copilot SHOULD be blocked from using web
    search for prompts that contain sensitive information types. If you allow web search, pair it
    with a Copilot DLP rule that blocks web search for sensitive prompts (MP.AIGOV.1043 checks that).

    This API supports delegated permissions only. In an app-only run the test skips.
    .EXAMPLE
    Test-MPAIGOV1042
    .LINK
    https://learn.microsoft.com/microsoft-365/copilot/extensibility/api/admin-settings/resources/copilotpolicysetting
    .LINK
    https://learn.microsoft.com/copilot/plan/manage-public-web-access
    #>
    [MaesterTest(
        Id           = 'MP.AIGOV.1042',
        Title        = 'Web search in Copilot should be off, or limited to Web mode',
        Product      = 'entra',
        Feature      = 'agents',
        Area         = 'ai',
        ResourceType = 'Tenant',
        Severity     = 'Low',
        Control      = 'nist-800-53-r5:AC-4',
        Permission   = 'Graph:Delegated:CopilotPolicySettings.Read',
        Service      = 'Graph',
        Lifecycle    = 'Preview'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose 'Reading the Allow web search in Copilot policy setting.'
        $Setting = Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri 'copilot/admin/policySettings/microsoft.copilot.allowwebsearch' -DisableCache
    } catch {
        $Message = [string]$_.Exception.Message
        if ($Message -match '(?i)\b40[13]\b|forbidden|unauthorized|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized -Result (
                "Couldn't read the Copilot web search setting. This API supports delegated permissions only: run Maester signed in " +
                'with CopilotPolicySettings.Read and at least the Global Reader role.'
            )
        } elseif ($Message -match '(?i)\b502\b|tooManyGroupPolicies') {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason (
                'The tenant has more group-level Copilot policies than the policy settings API supports. Check the setting in the Microsoft 365 Apps admin center.'
            )
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }

    $Value = [string]$Setting.value
    switch ($Value) {
        '1' {
            Add-MtTestResultDetail -Result 'Well done. Web search is off for Microsoft 365 Copilot and Copilot Chat.'
            return $true
        }
        '2' {
            Add-MtTestResultDetail -Result (
                'Web search is off in Microsoft 365 Copilot Work mode and on in Web mode and Copilot Chat. ' +
                'Make sure a Copilot DLP rule blocks web search for prompts with sensitive information (MP.AIGOV.1043).'
            )
            return $true
        }
        default {
            $State = if ([string]::IsNullOrWhiteSpace($Value)) { 'not set by a tenant-level policy, so the default applies (on)' } else { "set to '$Value' (on)" }
            Add-MtTestResultDetail -Result (
                "Web search in Copilot is $State. Prompts that need web grounding are sent to Bing under consumer terms. " +
                "Turn it off, limit it to Web mode, or confirm a Copilot DLP rule blocks web search for sensitive prompts (MP.AIGOV.1043)."
            ) -Severity 'Low'
            return $false
        }
    }
}
