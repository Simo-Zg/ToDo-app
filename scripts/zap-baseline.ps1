[CmdletBinding()]
param(
  [string]$TargetUrl = $env:DAST_TARGET_URL,
  [string]$ZapPath = $env:ZAP_PATH,
  [string]$ReportDir,
  [int]$TimeoutSeconds = 300
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

function ConvertTo-CommandLineArgument {
  param([string]$Value)

  if ($Value -match '[\s"]') {
    return '"' + ($Value -replace '"', '\"') + '"'
  }

  return $Value
}

$zap = Resolve-ZapBat -Candidate $ZapPath
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$htmlReport = Join-Path $ReportDir "zap-$timestamp.html"

Write-Host "Running ZAP quick scan against $TargetUrl"
Write-Host "ZAP: $zap"
Write-Host "Timeout: $TimeoutSeconds seconds"

$zapDir = Split-Path $zap -Parent
$zapArgs = @("-cmd", "-quickurl", $TargetUrl, "-quickprogress", "-quickout", $htmlReport)
$zapArgumentLine = '"' + $zap + '" ' + (($zapArgs | ForEach-Object { ConvertTo-CommandLineArgument $_ }) -join " ")
$process = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", $zapArgumentLine) -WorkingDirectory $zapDir -NoNewWindow -PassThru

if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
  Write-Warning "ZAP scan timed out after $TimeoutSeconds seconds. Stopping process tree."
  & taskkill.exe /PID $process.Id /T /F 2>$null | Out-Null
  throw "ZAP scan timed out after $TimeoutSeconds seconds."
}

if ($process.ExitCode -ne 0) {
  throw "ZAP scan failed with exit code $($process.ExitCode)"
}

Write-Host "ZAP report: $htmlReport"
