[CmdletBinding()]
param(
  [string]$Distribution = "kali-linux",
  [string]$OpenClawWorkspace = "/home/Kali/.openclaw/workspace",
  [switch]$BindAllChannels
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$PromptRoot = Join-Path $ProjectRoot "openclaw"

if (-not (Test-Path $PromptRoot)) {
  throw "OpenClaw prompt directory was not found: $PromptRoot"
}

wsl -d $Distribution -- bash -lc "mkdir -p '$OpenClawWorkspace/devsecops-prompts/commands'"
if ($LASTEXITCODE -ne 0) {
  throw "Unable to prepare OpenClaw workspace in WSL distribution '$Distribution'."
}

$uncWorkspace = "\\wsl.localhost\$Distribution$($OpenClawWorkspace -replace '/', '\')"
$uncPromptDir = Join-Path $uncWorkspace "devsecops-prompts"
$uncCommandsDir = Join-Path $uncPromptDir "commands"

New-Item -ItemType Directory -Force -Path $uncCommandsDir | Out-Null
Copy-Item (Join-Path $PromptRoot "DEVSECOPS_AGENT.md") (Join-Path $uncPromptDir "DEVSECOPS_AGENT.md") -Force
Copy-Item (Join-Path $PromptRoot "COMMANDS.md") (Join-Path $uncPromptDir "COMMANDS.md") -Force
Copy-Item (Join-Path $PromptRoot "commands\*.md") $uncCommandsDir -Force

$agentsPath = Join-Path $uncWorkspace "AGENTS.md"
$marker = "<!-- DEVSECOPS_TODO_AGENT_PROMPTS -->"
$includeBlock = @"

$marker
## DevSecOps Todo command router

Before answering a message that starts with /start, /help, /status, /run_pipeline, /stop_pipeline, /retry_pipeline, /scan, /deploy, or /logs, read:

- devsecops-prompts/DEVSECOPS_AGENT.md
- devsecops-prompts/COMMANDS.md
- the matching file in devsecops-prompts/commands/

Treat Telegram, Slack, and Discord messages the same way. Use the scripts in D:\Projects\AI-Agent\scripts through powershell.exe when the requested action needs GitLab, Docker, ZAP, or notifications.
"@

if (-not (Test-Path $agentsPath)) {
  New-Item -ItemType File -Force -Path $agentsPath | Out-Null
}

$agentsText = Get-Content $agentsPath -Raw
if ($agentsText -notlike "*$marker*") {
  Add-Content $agentsPath $includeBlock
  Write-Host "Updated OpenClaw AGENTS.md with DevSecOps command router."
} else {
  Write-Host "OpenClaw AGENTS.md already contains the DevSecOps command router marker."
}

if ($BindAllChannels) {
  $bindings = @("telegram:*", "discord:*", "slack:*")
  foreach ($binding in $bindings) {
    Write-Host "Binding main agent to $binding"
    wsl -d $Distribution -- openclaw agents bind --agent main --bind $binding
  }
}

Write-Host "OpenClaw prompts installed in $OpenClawWorkspace/devsecops-prompts"
Write-Host "Recommended check: wsl -d $Distribution -- openclaw agents bindings"
