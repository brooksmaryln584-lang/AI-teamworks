# AI-teamworks receipt creator v1.2.0: client, model and provider are distinct.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9-]{0,31}$')][string]$Tool,
    [Parameter(Mandatory)][string]$AgentId,
    [Parameter(Mandatory)][string]$SessionId,
    [Parameter(Mandatory)][string]$RunId,
    [Parameter(Mandatory)][string]$Project,
    [Parameter(Mandatory)][string]$TaskId,
    [Parameter(Mandatory)][ValidateSet('executor', 'reviewer', 'solo')][string]$Role,
    [Parameter(Mandatory)][string]$OutputPath,
    [int]$MaxRounds = 6,
    [string]$Model = '',
    [string]$Provider = ''
)

$ErrorActionPreference = 'Stop'
$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

$receipt = [ordered]@{
    schema_version = 2
    identity = [ordered]@{
        tool = $Tool
        model = $Model
        provider = $Provider
        agent_id = $AgentId
        session_id = $SessionId
        run_id = $RunId
        process_id = $PID
    }
    project = (Resolve-Path -LiteralPath $Project).Path
    task = [ordered]@{
        task_id = $TaskId
        goal = ''
        role = $Role
        scope = @()
    }
    memory = [ordered]@{
        sources = @()
        findings = @()
        uncertainties = @()
    }
    coordination = [ordered]@{
        state = 'unverified'
        evidence = ''
        proxy_actions = @()
    }
    live_checks = @()
    execution = [ordered]@{
        max_rounds = $MaxRounds
        current_round = 0
        status = 'preflight'
        changed_files = @()
        tests = @()
    }
    review = [ordered]@{
        reviewer_id = $null
        subject_executor_id = $null
        subject_receipt_path = $null
        subject_receipt_sha256 = $null
        evidence = @()
        status = 'not_started'
    }
}

$receipt | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output $OutputPath
