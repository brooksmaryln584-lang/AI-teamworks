# AI hub immutable report creator v0.1.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Project,
    [Parameter(Mandatory)][string]$Slug,
    [ValidateSet('work', 'review', 'correction', 'audit', 'handoff')][string]$Kind = 'work',
    [string]$Title = '',
    [string]$RunId = ''
)

$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath $Project).Path
$reportDir = Join-Path $projectPath 'reports'
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

function ConvertTo-SafeName {
    param([string]$Value, [int]$MaxLength = 64)

    $safe = ($Value -replace '[^\p{L}\p{Nd}._-]+', '-').Trim('-', '.', '_')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        throw 'The value does not contain a usable report filename component.'
    }
    if ($safe.Length -gt $MaxLength) {
        $safe = $safe.Substring(0, $MaxLength).TrimEnd('-', '.', '_')
    }
    return $safe
}

$safeSlug = ConvertTo-SafeName $Slug
$safeRunId = if ($RunId) { ConvertTo-SafeName $RunId 48 } else { '' }
$createdAt = (Get-Date).ToString('o')
$stamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
$nameParts = @($stamp, $Kind, $safeSlug)
if ($safeRunId) { $nameParts += $safeRunId }
$baseName = $nameParts -join '-'
$reportTitle = if ($Title) { $Title } else { $Slug }

$content = @"
# $reportTitle

- report_contract: immutable-new-file
- created_at: $createdAt
- run_id: $RunId
- kind: $Kind

## Current Run Goal

Describe only the goal of this run.

## Actions Performed This Run

- Replace with actions actually performed in this run.

## Files Changed This Run

- Replace with files actually changed in this run.

## Verification Performed This Run

- Record exact commands, exit codes, and observed evidence from this run.

## Current Run Result

State the result supported by this run's evidence.

## Remaining Risks or Next Step

- Record only current limitations or the next bounded step.
"@

$encoding = New-Object System.Text.UTF8Encoding($true)
$bytes = $encoding.GetBytes($content)
$reportPath = $null
for ($attempt = 0; $attempt -lt 100; $attempt++) {
    $suffix = if ($attempt -eq 0) { '' } else { '-{0}' -f $attempt }
    $candidate = Join-Path $reportDir ($baseName + $suffix + '.md')
    try {
        $stream = [IO.File]::Open($candidate, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $stream.Write($bytes, 0, $bytes.Length) }
        finally { $stream.Dispose() }
        $reportPath = $candidate
        break
    }
    catch [IO.IOException] {
        continue
    }
}

if (-not $reportPath) {
    throw 'Could not allocate a unique report filename after 100 attempts.'
}

Write-Output $reportPath
