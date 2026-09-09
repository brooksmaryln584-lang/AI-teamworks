[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][ValidateSet('preflight', 'submission')][string]$Stage
)

$ErrorActionPreference = 'Stop'
$r = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()

function Require-Text($Value, $Name) {
    if ([string]::IsNullOrWhiteSpace([string]$Value)) { $script:failures.Add("Missing: $Name") }
}

function Require-Items($Value, $Name) {
    if ($null -eq $Value -or @($Value).Count -eq 0) { $script:failures.Add("Missing items: $Name") }
}

Require-Text $r.identity.tool 'identity.tool'
Require-Text $r.identity.agent_id 'identity.agent_id'
Require-Text $r.identity.session_id 'identity.session_id'
Require-Text $r.identity.run_id 'identity.run_id'
Require-Text $r.task.task_id 'task.task_id'
Require-Text $r.task.goal 'task.goal'
Require-Items $r.task.scope 'task.scope'
Require-Items $r.memory.sources 'memory.sources'
Require-Items $r.memory.findings 'memory.findings'
Require-Items $r.live_checks 'live_checks'
Require-Text $r.coordination.state 'coordination.state'
Require-Text $r.coordination.evidence 'coordination.evidence'

if ($Stage -eq 'submission') {
    Require-Items $r.execution.changed_files 'execution.changed_files'
    Require-Items $r.execution.tests 'execution.tests'
    if ($r.execution.status -ne 'submitted') {
        $failures.Add('execution.status must be submitted')
    }
    foreach ($changedFile in @($r.execution.changed_files)) {
        $action = 'modified'
        $pathValue = $changedFile
        if ($changedFile -isnot [string]) {
            $pathValue = $changedFile.path
            $action = [string]$changedFile.action
        }
        Require-Text $pathValue 'execution.changed_files[].path'
        if ($action -notin @('added', 'modified', 'deleted')) { $failures.Add("Invalid changed file action: $action") }
        $candidate = [string]$pathValue
        if (-not [IO.Path]::IsPathRooted($candidate)) { $candidate = Join-Path $r.project $candidate }
        if ($action -eq 'deleted') {
            if (Test-Path -LiteralPath $candidate) { $failures.Add("Deleted file still exists: $pathValue") }
        } elseif (-not (Test-Path -LiteralPath $candidate)) {
            $failures.Add("Changed file does not exist: $pathValue")
        }
    }
    foreach ($test in @($r.execution.tests)) {
        Require-Text $test.command 'execution.tests[].command'
        Require-Text $test.observed_at 'execution.tests[].observed_at'
        Require-Text $test.evidence 'execution.tests[].evidence'
        if ($null -eq $test.exit_code -or $test.exit_code -notmatch '^-?\d+$') {
            $failures.Add('execution.tests[].exit_code must be an integer')
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host ("Receipt validation passed for stage: {0}" -f $Stage)
