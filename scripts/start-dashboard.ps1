# AI-teamworks dashboard launcher v0.2.0
# Purpose: run the local viewer in the background without keeping a terminal open.
# Acceptance: health endpoint responds on loopback; PID/log paths are printed.
[CmdletBinding()]
param(
    [ValidateRange(1,65535)][int]$Port = 8787,
    [string]$CoordUrl = 'http://127.0.0.1:7777/',
    [switch]$Demo,
    [switch]$OpenBrowser
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$python = (Get-Command python -ErrorAction Stop).Source
$parsed = [uri]$CoordUrl
if ($parsed.Scheme -ne 'http' -or $parsed.Host -notin @('127.0.0.1','localhost') -or $parsed.UserInfo -or $parsed.Query -or $parsed.Fragment -or $parsed.AbsolutePath -ne '/') {
    throw 'CoordUrl must be an HTTP loopback root URL without credentials.'
}
$runDir = Join-Path $repo ('runs/dashboard-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$serverRecord = Join-Path $runDir 'server.json'
$arguments = @('-m', 'dashboard.server', '--port', [string]$Port, '--coord-url', $parsed.AbsoluteUri, '--process-file', ('"' + $serverRecord + '"'))
if ($Demo) { $arguments += '--demo' }
if ($OpenBrowser) { $arguments += '--open' }
$process = Start-Process -FilePath $python -ArgumentList $arguments -WorkingDirectory $repo -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runDir 'stdout.log') -RedirectStandardError (Join-Path $runDir 'stderr.log')
for ($attempt = 0; $attempt -lt 50; $attempt++) {
    if (Test-Path -LiteralPath $serverRecord) { break }
    if ($process.HasExited) { break }
    Start-Sleep -Milliseconds 100
}
if (-not (Test-Path -LiteralPath $serverRecord)) { throw ('Dashboard did not start. Check ' + (Join-Path $runDir 'stderr.log')) }
# The server reports its own PID; Python shims may report themselves in sys.executable.
$serverIdentity = Get-Content -Raw -LiteralPath $serverRecord | ConvertFrom-Json
$serverProcess = Get-Process -Id $serverIdentity.pid -ErrorAction Stop
$record = [ordered]@{ pid=$serverProcess.Id; started_at=$serverProcess.StartTime.ToString('o'); port=$Port; demo=[bool]$Demo; coord_url=$parsed.AbsoluteUri; directory=$repo }
$record | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $runDir 'process.json')
Write-Output ('Window: http://127.0.0.1:' + $Port + '/')
Write-Output ('Process: ' + $serverProcess.Id + '; record: ' + (Join-Path $runDir 'process.json'))
Write-Output 'Before stopping this PID, confirm its start time and command line match this record.'
