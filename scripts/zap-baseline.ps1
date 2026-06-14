[CmdletBinding()]
param(
  [string]$TargetUrl = $env:DAST_TARGET_URL,
  [string]$ZapPath = $env:ZAP_PATH,
  [string]$ReportDir,
  [int]$TimeoutSeconds = 300,
  [int]$ZapPort = 8090,
  [bool]$FailOnTimeout = $false
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
$summaryReport = Join-Path $ReportDir "zap-summary-$timestamp.txt"

Write-Host "Running ZAP passive baseline against $TargetUrl"
Write-Host "ZAP: $zap"
Write-Host "ZAP API: http://127.0.0.1:$ZapPort"
Write-Host "Timeout: $TimeoutSeconds seconds"

$zapDir = Split-Path $zap -Parent
$zapArgs = @(
  "-daemon",
  "-host", "127.0.0.1",
  "-port", "$ZapPort",
  "-config", "api.disablekey=true",
  "-config", "database.recoverylog=false"
)
$zapArgumentLine = '"' + $zap + '" ' + (($zapArgs | ForEach-Object { ConvertTo-CommandLineArgument $_ }) -join " ")
$process = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", $zapArgumentLine) -WorkingDirectory $zapDir -WindowStyle Hidden -PassThru

try {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $apiBase = "http://127.0.0.1:$ZapPort"
  $versionUri = "$apiBase/JSON/core/view/version/"

  while ((Get-Date) -lt $deadline) {
    try {
      $version = Invoke-RestMethod -Uri $versionUri -TimeoutSec 3
      if ($version.version) {
        Write-Host "ZAP daemon is ready: $($version.version)"
        break
      }
    } catch {
      Start-Sleep -Seconds 2
    }
  }

  if ((Get-Date) -ge $deadline) {
    if ($FailOnTimeout) {
      throw "ZAP daemon did not become ready within $TimeoutSeconds seconds."
    }
    "ZAP daemon startup timed out after $TimeoutSeconds seconds." | Set-Content -Path $summaryReport
    Write-Warning "ZAP daemon startup timed out. Summary: $summaryReport"
    return
  }

  Write-Host "Sending target request through ZAP proxy..."
  try {
    Invoke-WebRequest -Uri $TargetUrl -Proxy "http://127.0.0.1:$ZapPort" -UseBasicParsing -TimeoutSec 20 | Out-Null
  } catch {
    Write-Warning "The proxied target request failed: $($_.Exception.Message)"
  }

  Start-Sleep -Seconds 5
  $encodedTarget = [System.Uri]::EscapeDataString($TargetUrl)
  $alertsResponse = Invoke-RestMethod -Uri "$apiBase/JSON/core/view/alerts/?baseurl=$encodedTarget" -TimeoutSec 15
  $alerts = @($alertsResponse.alerts)
  $highCount = @($alerts | Where-Object { $_.risk -eq "High" }).Count
  $mediumCount = @($alerts | Where-Object { $_.risk -eq "Medium" }).Count
  $lowCount = @($alerts | Where-Object { $_.risk -eq "Low" }).Count

  $html = (Invoke-WebRequest -Uri "$apiBase/OTHER/core/other/htmlreport/" -UseBasicParsing -TimeoutSec 30).Content
  Set-Content -Path $htmlReport -Value $html

  @(
    "ZAP passive baseline completed.",
    "TargetUrl=$TargetUrl",
    "CompletedAt=$(Get-Date -Format o)",
    "HighAlerts=$highCount",
    "MediumAlerts=$mediumCount",
    "LowAlerts=$lowCount",
    "HtmlReport=$htmlReport"
  ) | Set-Content -Path $summaryReport

  Write-Host "ZAP summary: $summaryReport"
  Write-Host "ZAP report: $htmlReport"
} finally {
  try {
    Invoke-RestMethod -Uri "http://127.0.0.1:$ZapPort/JSON/core/action/shutdown/" -TimeoutSec 5 | Out-Null
  } catch {
    Write-Warning "ZAP API shutdown failed or ZAP was already stopped: $($_.Exception.Message)"
  }

  Start-Sleep -Seconds 3
  if (-not $process.HasExited) {
    Start-Process -FilePath "taskkill.exe" -ArgumentList @("/PID", "$($process.Id)", "/T", "/F") -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
  }
}
