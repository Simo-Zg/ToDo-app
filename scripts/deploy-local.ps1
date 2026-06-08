[CmdletBinding()]
param(
  [ValidateSet("local", "staging", "production")]
  [string]$Environment = "staging"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $ProjectRoot

if (-not (Test-Path ".env")) {
  throw ".env is missing. Run scripts\install.ps1 first."
}

$env:COMPOSE_PROJECT_NAME = "todo-$Environment"
docker compose up -d --build

if ($LASTEXITCODE -ne 0) {
  throw "Docker Compose deployment failed."
}

& (Join-Path $PSScriptRoot "wait-http.ps1") -Url "http://127.0.0.1:5000/health" -TimeoutSeconds 120
& (Join-Path $PSScriptRoot "notify-telegram.ps1") -Message "Deployment '$Environment' completed for Todo app. URL: http://127.0.0.1:5000"

Write-Host "Deployment completed: $Environment"
