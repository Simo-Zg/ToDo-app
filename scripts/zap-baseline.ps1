[CmdletBinding()]
param(
  [string]$TargetUrl = $env:DAST_TARGET_URL,
  [string]$ZapPath = $env:ZAP_PATH,
  [string]$ReportDir
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "load-env.ps1")

if ([string]::IsNullOrWhiteSpace($TargetUrl)) {
  $TargetUrl = $env:DAST_TARGET_URL
}

if ([string]::IsNullOrWhiteSpace($ZapPath)) {
  $ZapPath = $env:ZAP_PATH
}

if ([string]::IsNullOrWhiteSpace($TargetUrl)) {
  $TargetUrl = "http://127.0.0.1:5000"
}

if ([string]::IsNullOrWhiteSpace($ReportDir)) {
  $ReportDir = Join-Path $ProjectRoot "reports\zap"
}

function Resolve-ZapBat {
  param([string]$Candidate)

  if ($Candidate -and (Test-Path $Candidate)) {
    return (Resolve-Path $Candidate).Path
  }

  $commonPaths = @(
    "C:\Program Files\ZAP\Zed Attack Proxy\zap.bat",
    "C:\Program Files\OWASP\Zed Attack Proxy\zap.bat",
    "C:\Program Files (x86)\OWASP\Zed Attack Proxy\zap.bat",
    "C:\Program Files\Zed Attack Proxy\zap.bat"
  )

  foreach ($path in $commonPaths) {
    if (Test-Path $path) {
      return $path
    }
  }

  throw "ZAP was not found. Set ZAP_PATH to the full path of zap.bat."
}

$zap = Resolve-ZapBat -Candidate $ZapPath
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$htmlReport = Join-Path $ReportDir "zap-$timestamp.html"

Write-Host "Running ZAP quick scan against $TargetUrl"
Write-Host "ZAP: $zap"

$zapDir = Split-Path $zap -Parent
Push-Location $zapDir
try {
  & $zap -cmd -quickurl $TargetUrl -quickprogress -quickout $htmlReport
} finally {
  Pop-Location
}

if ($LASTEXITCODE -ne 0) {
  throw "ZAP scan failed with exit code $LASTEXITCODE"
}

Write-Host "ZAP report: $htmlReport"
