[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ExecutorReceipt,
    [Parameter(Mandatory)][string]$ReviewerReceipt
)

$ErrorActionPreference = 'Stop'
$executor = Get-Content -Raw -Encoding UTF8 -LiteralPath $ExecutorReceipt | ConvertFrom-Json
$reviewer = Get-Content -Raw -Encoding UTF8 -LiteralPath $ReviewerReceipt | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()

function Require-Text($Value, $Name) {
    if ([string]::IsNullOrWhiteSpace([string]$Value)) { $script:failures.Add("Missing: $Name") }
}

function Get-Sha256($Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead((Resolve-Path -LiteralPath $Path).Path)
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}

Require-Text $executor.identity.agent_id 'executor.identity.agent_id'
Require-Text $reviewer.identity.agent_id 'reviewer.identity.agent_id'
Require-Text $reviewer.task.goal 'reviewer.task.goal'
if (@($reviewer.task.scope).Count -eq 0) { $failures.Add('Reviewer scope is required') }
if (@($reviewer.memory.sources).Count -eq 0) { $failures.Add('Reviewer memory sources are required') }
if (@($reviewer.memory.findings).Count -eq 0) { $failures.Add('Reviewer memory findings are required') }
Require-Text $reviewer.coordination.evidence 'reviewer.coordination.evidence'
if ($executor.identity.agent_id -eq $reviewer.identity.agent_id) { $failures.Add('Reviewer identity must differ from executor identity') }
if ($executor.task.task_id -ne $reviewer.task.task_id) { $failures.Add('Task IDs do not match') }
if ($executor.execution.status -ne 'submitted') { $failures.Add('Executor receipt must be submitted') }
if ($reviewer.task.role -ne 'reviewer') { $failures.Add('Reviewer receipt role must be reviewer') }
if ($reviewer.review.status -ne 'verified') { $failures.Add('Reviewer receipt status must be verified') }
if ($reviewer.review.subject_executor_id -ne $executor.identity.agent_id) { $failures.Add('subject_executor_id does not match executor') }
Require-Text $reviewer.review.subject_receipt_path 'review.subject_receipt_path'
Require-Text $reviewer.review.subject_receipt_sha256 'review.subject_receipt_sha256'
if ($reviewer.review.subject_receipt_sha256 -ne (Get-Sha256 $ExecutorReceipt)) { $failures.Add('Executor receipt hash mismatch') }
if (@($reviewer.review.evidence).Count -eq 0) { $failures.Add('Reviewer evidence is required') }
if (@($reviewer.live_checks).Count -eq 0) { $failures.Add('Reviewer live checks are required') }

foreach ($test in @($executor.execution.tests)) {
    if ($executor.schema_version -ge 2) {
        Require-Text $test.command 'executor.execution.tests[].command'
        Require-Text $test.observed_at 'executor.execution.tests[].observed_at'
        Require-Text $test.evidence 'executor.execution.tests[].evidence'
        if ($test.exit_code -ne 0) { $failures.Add('Executor has a non-zero test result') }
    }
}
foreach ($changedFile in @($executor.execution.changed_files)) {
    $action = 'modified'
    $pathValue = $changedFile
    if ($changedFile -isnot [string]) {
        $pathValue = $changedFile.path
        $action = [string]$changedFile.action
    }
    $candidate = [string]$pathValue
    if (-not [IO.Path]::IsPathRooted($candidate)) { $candidate = Join-Path $executor.project $candidate }
    if ($action -eq 'deleted') {
        if (Test-Path -LiteralPath $candidate) { $failures.Add("Executor deleted file still exists: $pathValue") }
    } elseif (-not (Test-Path -LiteralPath $candidate)) {
        $failures.Add("Executor changed file does not exist: $pathValue")
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host 'Independent review pair validation passed.'
