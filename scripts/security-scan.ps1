[CmdletBinding()]
param(
  [ValidateSet("all", "dependencies", "secrets", "sast", "docker", "zap")]
  [string]$Mode = "all",

  [string]$ImageName = "todo-app:security",
  [string]$TargetUrl = $env:DAST_TARGET_URL
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $ProjectRoot
. (Join-Path $PSScriptRoot "load-env.ps1")

if ([string]::IsNullOrWhiteSpace($TargetUrl)) {
  $TargetUrl = $env:DAST_TARGET_URL
}

if ([string]::IsNullOrWhiteSpace($TargetUrl)) {
  $TargetUrl = "http://127.0.0.1:5000"
}

$ReportsRoot = Join-Path $ProjectRoot "reports"
New-Item -ItemType Directory -Force -Path $ReportsRoot | Out-Null

$Failures = New-Object System.Collections.Generic.List[string]

function Invoke-ScanStep {
  param(
    [string]$Name,
    [scriptblock]$Body
  )

  Write-Host ""
  Write-Host "== $Name =="
  try {
    & $Body
    Write-Host "$Name completed."
  } catch {
    $Failures.Add("${Name}: $($_.Exception.Message)")
    Write-Error "$Name failed: $($_.Exception.Message)" -ErrorAction Continue
  }
}

function Should-Run {
  param([string]$Step)
  return $Mode -eq "all" -or $Mode -eq $Step
}

if (Should-Run "dependencies") {
  Invoke-ScanStep "Dependency scan (npm audit)" {
    $dir = Join-Path $ReportsRoot "npm-audit"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $output = & npm audit --audit-level=high --json 2>&1
    $output | Set-Content (Join-Path $dir "npm-audit.json")
    if ($LASTEXITCODE -ne 0) {
      throw "npm audit found high or critical dependency vulnerabilities."
    }
  }
}

if (Should-Run "secrets") {
  Invoke-ScanStep "Secret scan (Gitleaks)" {
    $dir = Join-Path $ReportsRoot "gitleaks"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    & docker run --rm -v "${ProjectRoot}:/repo" zricethezav/gitleaks:latest detect `
      --source=/repo `
      --no-git `
      --redact `
      --report-format=json `
      --report-path=/repo/reports/gitleaks/gitleaks.json
    if ($LASTEXITCODE -ne 0) {
      throw "Gitleaks detected a secret or failed to run."
    }
  }
}

if (Should-Run "sast") {
  Invoke-ScanStep "SAST scan (Semgrep)" {
    $dir = Join-Path $ReportsRoot "semgrep"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    & docker run --rm -v "${ProjectRoot}:/src" --workdir /src semgrep/semgrep:latest semgrep scan `
      --config p/nodejs `
      --config p/owasp-top-ten `
      --json `
      --output /src/reports/semgrep/semgrep.json `
      /src
    if ($LASTEXITCODE -ne 0) {
      throw "Semgrep found blocking issues or failed to run."
    }
  }
}

if (Should-Run "docker") {
  Invoke-ScanStep "Docker image scan (Trivy)" {
    $dir = Join-Path $ReportsRoot "trivy"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $imageTar = Join-Path $dir "todo-app.tar"

    docker build -t $ImageName .
    if ($LASTEXITCODE -ne 0) {
      throw "Docker build failed."
    }

    docker save $ImageName -o $imageTar
    if ($LASTEXITCODE -ne 0) {
      throw "Docker save failed."
    }

    & docker run --rm -v "${dir}:/reports" aquasec/trivy:latest image `
      --input /reports/todo-app.tar `
      --severity HIGH,CRITICAL `
      --format json `
      --output /reports/trivy-image.json `
      --exit-code 1
    if ($LASTEXITCODE -ne 0) {
      throw "Trivy found high or critical image vulnerabilities."
    }
  }
}

if (Should-Run "zap") {
  Invoke-ScanStep "DAST scan (OWASP ZAP)" {
    & (Join-Path $PSScriptRoot "zap-baseline.ps1") -TargetUrl $TargetUrl
  }
}

if ($Failures.Count -gt 0) {
  $message = "DevSecOps scan failed:`n" + ($Failures -join "`n")
  & (Join-Path $PSScriptRoot "notify-telegram.ps1") -Message $message
  throw ($Failures -join "; ")
}

Write-Host ""
Write-Host "All requested security scans completed successfully."
