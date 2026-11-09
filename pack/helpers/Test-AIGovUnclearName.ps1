function Test-AIGovUnclearName {
    <#
    .SYNOPSIS
    Returns $true when a name gives reviewers nothing to go on.
    .DESCRIPTION
    The "unclear name" rule from chadmcox/Copilot "Agent and Tools Health Check" (that repo's list, not
    Microsoft's; Microsoft recommends a naming convention but publishes no word list): empty, fewer than 4
    characters, contains a word starting with test, demo, sample or sandbox, or the words temp, tmp, copy,
    draft, POC, untitled, dummy, delete me or do not use; starts with new/my agent, plugin, skill or bot;
    or ends with a number after agent/plugin/skill/bot, or a copy marker such as (1).
    The " (Microsoft Copilot Studio)" suffix that Copilot Studio adds to agent identity names is ignored.
    .EXAMPLE
    Test-AIGovUnclearName -Name $Agent.displayName
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Name
    )

    $Clean = ([string]$Name -replace '\s*\(Microsoft Copilot Studio\)\s*$', '').Trim()
    if ($Clean.Length -lt 4) { return $true }
    $Pattern = '(?i)\b(test\w*|demo\w*|temp\b|tmp\b|copy\b|draft\b|sample\w*|poc\b|sandbox\w*|untitled\b|dummy\b|delete ?me\b|do not use\b)|^(new|my) (agent|plugin|skill|bot)\b|\b(agent|plugin|skill|bot) ?\d+$|\(\d+\)$'
    return [bool]($Clean -match $Pattern)
}
