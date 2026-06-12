[CmdletBinding()]
param(
  [ValidateSet("all", "dependencies", "secrets", "sast", "semgrep", "sonarqube", "docker", "zap")]
  [string]$Mode = "all",

  [string]$ImageName = "todo-app:security",
  [string]$TargetUrl = $env:DAST_TARGET_URL,
  [string]$SastScanners = $env:SAST_SCANNERS
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

if ([string]::IsNullOrWhiteSpace($SastScanners)) {
  $SastScanners = "semgrep,sonarqube"
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

function Ensure-DockerImage {
  param([string]$Image)

  docker image inspect $Image *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker image not found locally. Pulling $Image..."
    docker pull $Image
    if ($LASTEXITCODE -ne 0) {
      throw "Unable to pull Docker image $Image."
    }
  }
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

if ((Should-Run "sast") -or (Should-Run "semgrep")) {
  Invoke-ScanStep "SAST scan (Semgrep)" {
    $dir = Join-Path $ReportsRoot "semgrep"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    Ensure-DockerImage "semgrep/semgrep:latest"

    if ($SastScanners -notmatch "(^|,)semgrep(,|$)" -and $Mode -ne "semgrep" -and $Mode -ne "all") {
      Write-Host "Semgrep skipped because SAST_SCANNERS=$SastScanners"
      return
    }

    $dockerArgs = @("run", "--rm", "-v", "${ProjectRoot}:/src", "--workdir", "/src")

    if (-not [string]::IsNullOrWhiteSpace($env:SEMGREP_APP_TOKEN)) {
      $dockerArgs += @("-e", "SEMGREP_APP_TOKEN=$env:SEMGREP_APP_TOKEN")
      $dockerArgs += @("semgrep/semgrep:latest", "semgrep", "ci", "--json", "--output", "/src/reports/semgrep/semgrep.json")
    } else {
      $dockerArgs += @(
        "semgrep/semgrep:latest",
        "semgrep",
        "scan",
        "--config",
        "p/nodejs",
        "--config",
        "p/owasp-top-ten",
        "--json",
        "--output",
        "/src/reports/semgrep/semgrep.json",
        "/src"
      )
    }

    & docker @dockerArgs
    if ($LASTEXITCODE -ne 0) {
      throw "Semgrep found blocking issues or failed to run."
    }
  }
}

if ((Should-Run "sast") -or (Should-Run "sonarqube")) {
  Invoke-ScanStep "SAST scan (SonarQube)" {
    $dir = Join-Path $ReportsRoot "sonarqube"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    if ($SastScanners -notmatch "(^|,)sonarqube(,|$)" -and $Mode -ne "sonarqube" -and $Mode -ne "all") {
      Write-Host "SonarQube skipped because SAST_SCANNERS=$SastScanners"
      return
    }

    $sonarHostUrl = $env:SONAR_HOST_URL
    if ([string]::IsNullOrWhiteSpace($sonarHostUrl)) {
      $sonarHostUrl = "http://host.docker.internal:9000"
    }

    if ([string]::IsNullOrWhiteSpace($env:SONAR_TOKEN)) {
      throw "SONAR_TOKEN is missing. Add it as a masked GitLab CI/CD variable or local .env value."
    }

    $projectKey = $env:SONAR_PROJECT_KEY
    if ([string]::IsNullOrWhiteSpace($projectKey)) {
      $projectKey = "todo-devsecops"
    }

    Ensure-DockerImage "sonarsource/sonar-scanner-cli:latest"

    & docker run --rm `
      -e "SONAR_HOST_URL=$sonarHostUrl" `
      -e "SONAR_TOKEN=$env:SONAR_TOKEN" `
      -e "SONAR_SCANNER_OPTS=-Dsonar.projectBaseDir=/usr/src" `
      -v "${ProjectRoot}:/usr/src" `
      sonarsource/sonar-scanner-cli:latest `
      -Dsonar.projectKey=$projectKey `
      -Dsonar.projectName=Todo-DevSecOps `
      -Dsonar.sources=. `
      -Dsonar.exclusions=node_modules/**,reports/**,coverage/**,.git/**,docs/FINAL_REPORT.html

    if ($LASTEXITCODE -ne 0) {
      throw "SonarQube scan failed or quality gate rejected the analysis."
    }

    $summaryPath = Join-Path $dir "sonarqube-summary.txt"
    @(
      "SONAR_HOST_URL=$sonarHostUrl",
      "SONAR_PROJECT_KEY=$projectKey",
      "CompletedAt=$(Get-Date -Format o)"
    ) | Set-Content $summaryPath
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
