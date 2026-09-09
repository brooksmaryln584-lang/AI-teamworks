# Public toolkit smoke evaluation v0.1.0
# Purpose: check positive/negative receipts and immutable report allocation.
# Acceptance: every case prints PASS; process exits 0.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$scriptRoot = Join-Path $root 'skills/shared/memory-first-coordination/scripts'
$session = [guid]::NewGuid().ToString('N')
$work = Join-Path $root ('runs/toolkit-eval-' + $session)
New-Item -ItemType Directory -Path $work -Force | Out-Null
$shellExe = (Get-Process -Id $PID).Path
$receiptPath = Join-Path $work 'executor.json'
& (Join-Path $scriptRoot 'new_receipt.ps1') -Tool codex -AgentId ('executor-' + $session) -SessionId $session -RunId $session -Project $root -TaskId ('eval-' + $session) -Role executor -OutputPath $receiptPath | Out-Null
$r = Get-Content -Raw -LiteralPath $receiptPath | ConvertFrom-Json
$r.task.goal = 'Synthetic fixture for structural checks; not a real review'
$r.task.scope = @('README.md')
$r.memory.sources = @('README.md')
$r.memory.findings = @('Synthetic fixture')
$r.coordination.state = 'offline-fallback'
$r.coordination.evidence = 'Isolated local test fixture, no live agents'
$r.live_checks = @('README exists')
$r.execution.status = 'submitted'
$r.execution.changed_files = @(@{path='README.md';action='modified'})
$r.execution.tests = @(@{command='synthetic fixture';exit_code=0;observed_at=(Get-Date).ToString('o');evidence='Structural test only'})
$r | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
function Check-Exit([string]$Name, [string]$Script, [string[]]$Arguments, [int]$Expected) {
 $output = & $shellExe -NoProfile -File $Script @Arguments 2>&1
 if ($LASTEXITCODE -ne $Expected) { throw "$Name expected $Expected, got $LASTEXITCODE : $output" }
 Write-Host "PASS $Name"
}
$validator = Join-Path $scriptRoot 'validate_receipt.ps1'
Check-Exit 'valid preflight' $validator @('-Path',$receiptPath,'-Stage','preflight') 0
Check-Exit 'valid submission' $validator @('-Path',$receiptPath,'-Stage','submission') 0
$r.memory.findings = @()
$invalidPath = Join-Path $work 'invalid.json'
$r | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $invalidPath -Encoding UTF8
Check-Exit 'reject missing memory' $validator @('-Path',$invalidPath,'-Stage','preflight') 1
$reviewer = Get-Content -Raw -LiteralPath $receiptPath | ConvertFrom-Json
$reviewer.identity.agent_id = 'reviewer-' + $session
$reviewer.task.role = 'reviewer'
$reviewer.review.status = 'verified'
$reviewer.review.subject_executor_id = 'executor-' + $session
$reviewer.review.subject_receipt_path = $receiptPath
$reviewer.review.subject_receipt_sha256 = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
$reviewer.review.evidence = @('Synthetic pair for schema validation; not independent real review')
$reviewPath = Join-Path $work 'reviewer.json'
$reviewer | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reviewPath -Encoding UTF8
$pair = Join-Path $scriptRoot 'validate_review_pair.ps1'
Check-Exit 'valid synthetic pair' $pair @('-ExecutorReceipt',$receiptPath,'-ReviewerReceipt',$reviewPath) 0
$reviewer.identity.agent_id = 'executor-' + $session
$reviewer | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reviewPath -Encoding UTF8
Check-Exit 'reject self review' $pair @('-ExecutorReceipt',$receiptPath,'-ReviewerReceipt',$reviewPath) 1
$reviewer.identity.agent_id = 'reviewer-' + $session
$reviewer.review.subject_receipt_sha256 = '0' * 64
$reviewer | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reviewPath -Encoding UTF8
Check-Exit 'reject wrong hash' $pair @('-ExecutorReceipt',$receiptPath,'-ReviewerReceipt',$reviewPath) 1
$creator = Join-Path $root 'scripts/new-report.ps1'
$first = & $creator -Project $work -Slug same-name -RunId $session
$hash = (Get-FileHash -LiteralPath $first).Hash
$second = & $creator -Project $work -Slug same-name -RunId $session
if ($first -eq $second -or (Get-FileHash -LiteralPath $first).Hash -ne $hash) { throw 'Report overwritten' }
Write-Host 'PASS reports allocated separately; previous report hash unchanged'
Write-Host '7 checks passed. Synthetic fixtures remain in ignored runs directory.'
