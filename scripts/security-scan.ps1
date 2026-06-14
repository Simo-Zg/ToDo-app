[CmdletBinding()]
param(
  [ValidateSet("all", "dependencies", "secrets", "sast", "semgrep", "sonarqube", "docker", "zap")]
  [string]$Mode = "all",

  [string]$ImageName = "todo-app:security",
  [string]$TargetUrl = $env:DAST_TARGET_URL,
  [string]$SastScanners = $env:SAST_SCANNERS,
  [int]$ZapTimeoutSeconds = 300
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
  $SastScanners = "semgrep"
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

  $inspectExitCode = Invoke-ProcessWithTimeout `
    -FilePath "docker" `
    -Arguments @("image", "inspect", "--format", "{{.Id}}", $Image) `
    -TimeoutSeconds 60 `
    -Description "Docker image inspect $Image"

  if ($inspectExitCode -ne 0) {
    Write-Host "Docker image not found locally. Pulling $Image..."
    $pullExitCode = Invoke-ProcessWithTimeout `
      -FilePath "docker" `
      -Arguments @("pull", $Image) `
      -TimeoutSeconds 600 `
      -Description "Docker pull $Image"
    if ($pullExitCode -ne 0) {
      throw "Unable to pull Docker image $Image."
    }
  }
}

function ConvertTo-CommandLineArgument {
  param([string]$Value)

  if ($Value -match '[\s"]') {
    return '"' + ($Value -replace '"', '\"') + '"'
  }

  return $Value
}

function Invoke-ProcessWithTimeout {
  param(
    [string]$FilePath,
    [string[]]$Arguments,
    [int]$TimeoutSeconds = 120,
    [string]$Description = $FilePath
  )

  $argumentLine = ($Arguments | ForEach-Object { ConvertTo-CommandLineArgument $_ }) -join " "
  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = $FilePath
  $startInfo.Arguments = $argumentLine
  $startInfo.UseShellExecute = $false

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $startInfo
  [void]$process.Start()

  if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    try {
      & taskkill.exe /PID $process.Id /T /F 2>$null | Out-Null
    } catch {
      Write-Warning "Unable to kill timed-out process: $($_.Exception.Message)"
    }
    throw "$Description timed out after $TimeoutSeconds seconds."
  }

  $process.Refresh()
  if ($null -eq $process.ExitCode) {
    throw "$Description completed without an exit code."
  }
  return [int]$process.ExitCode
}

function Invoke-DockerWithTimeout {
  param(
    [string[]]$Arguments,
    [string]$ContainerName,
    [int]$TimeoutSeconds = 120
  )

  $argumentLine = ($Arguments | ForEach-Object { ConvertTo-CommandLineArgument $_ }) -join " "
  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = "docker"
  $startInfo.Arguments = $argumentLine
  $startInfo.UseShellExecute = $false

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $startInfo
  [void]$process.Start()

  if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    Write-Warning "Docker command timed out after $TimeoutSeconds seconds. Stopping container $ContainerName."
    & docker stop $ContainerName 2>$null | Out-Null
    try {
      & taskkill.exe /PID $process.Id /T /F 2>$null | Out-Null
    } catch {
      Write-Warning "Unable to kill docker process: $($_.Exception.Message)"
    }
    return 124
  }

  $process.Refresh()
  if ($null -eq $process.ExitCode) {
    throw "Docker command completed without an exit code."
  }
  return [int]$process.ExitCode
}

if (Should-Run "dependencies") {
  Invoke-ScanStep "Dependency scan (npm audit)" {
    $dir = Join-Path $ReportsRoot "npm-audit"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $reportPath = Join-Path $dir "npm-audit.json"
    $maxAttempts = 3

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
      $output = & npm audit --audit-level=high --json 2>&1
      $exitCode = $LASTEXITCODE
      $output | Set-Content $reportPath

      if ($exitCode -eq 0) {
        break
      }

      $outputText = $output -join "`n"
      $isTransientNetworkFailure = $outputText -match "(?i)(ENOTFOUND|EAI_AGAIN|ECONNRESET|ETIMEDOUT|socket hang up|network timeout|registry\.npmjs\.org)"
      if ($isTransientNetworkFailure -and $attempt -lt $maxAttempts) {
        Write-Warning "npm audit failed because of a transient network/DNS error. Retrying attempt $($attempt + 1) of $maxAttempts..."
        Start-Sleep -Seconds (10 * $attempt)
        continue
      }

      if ($isTransientNetworkFailure) {
        throw "npm audit failed after $maxAttempts attempts because the runner could not reach registry.npmjs.org."
      }

      throw "npm audit found high or critical dependency vulnerabilities."
    }
  }
}

if (Should-Run "secrets") {
  Invoke-ScanStep "Secret scan (Gitleaks)" {
    $dir = Join-Path $ReportsRoot "gitleaks"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Ensure-DockerImage "zricethezav/gitleaks:latest"
    & docker run --rm -v "${ProjectRoot}:/repo" zricethezav/gitleaks:latest detect `
      --source=/repo `
      --config=/repo/.gitleaks.toml `
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
        "/src/.semgrep.yml",
        "--timeout",
        "60",
        "--jobs",
        "1",
        "--json",
        "--output",
        "/src/reports/semgrep/semgrep.json",
        "/src/server.js",
        "/src/controllers",
        "/src/middleware",
        "/src/Model",
        "/src/utils",
        "/src/public/Scripts"
      )
    }

    & docker @dockerArgs
    $semgrepExitCode = $LASTEXITCODE
    if ($semgrepExitCode -ne 0) {
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

    if ([string]::IsNullOrWhiteSpace($env:SONAR_TOKEN) -and $Mode -eq "sonarqube") {
      throw "SONAR_TOKEN is missing. Add it as a masked GitLab CI/CD variable or local .env value."
    }

    if ([string]::IsNullOrWhiteSpace($env:SONAR_TOKEN)) {
      Write-Host "SonarQube skipped because SONAR_TOKEN is not configured."
      return
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

    docker build -t $ImageName .
    if ($LASTEXITCODE -ne 0) {
      throw "Docker build failed."
    }

    Ensure-DockerImage "aquasec/trivy:latest"

    $trivyCacheDir = $env:TRIVY_CACHE_DIR
    if ([string]::IsNullOrWhiteSpace($trivyCacheDir)) {
      $trivyCacheDir = Join-Path $ProjectRoot ".trivy-cache"
    }
    New-Item -ItemType Directory -Force -Path $trivyCacheDir | Out-Null

    $trivyDbRepository = $env:TRIVY_DB_REPOSITORY
    if ([string]::IsNullOrWhiteSpace($trivyDbRepository)) {
      $trivyDbRepository = "ghcr.io/aquasecurity/trivy-db:2"
    }

    $trivyDbMetadata = Join-Path $trivyCacheDir "db\metadata.json"
    $trivyDbArgs = @("--db-repository", $trivyDbRepository)
    if (Test-Path -LiteralPath $trivyDbMetadata) {
      $trivyDbArgs = @("--skip-db-update")
    }

    $jsonReport = Join-Path $dir "trivy-image.json"
    $tableReport = Join-Path $dir "trivy-image.txt"
    Remove-Item -LiteralPath $jsonReport, $tableReport -Force -ErrorAction SilentlyContinue

    $trivyRunPrefix = @(
      "run", "--rm",
      "-v", "/var/run/docker.sock:/var/run/docker.sock",
      "-v", "${dir}:/reports",
      "-v", "${trivyCacheDir}:/root/.cache/trivy"
    )

    $trivyScanArgs = @(
      "aquasec/trivy:latest",
      "image"
    ) + $trivyDbArgs + @(
      "--no-progress",
      "--scanners", "vuln",
      "--severity", "HIGH,CRITICAL",
      "--timeout", "5m"
    )

    $trivyContainerName = "todo-app-trivy-$([Guid]::NewGuid().ToString('N'))"
    $trivyExitCode = Invoke-DockerWithTimeout `
      -ContainerName $trivyContainerName `
      -TimeoutSeconds 600 `
      -Arguments ($trivyRunPrefix + @(
        "--name", $trivyContainerName
      ) + $trivyScanArgs + @(
        "--format", "json",
        "--output", "/reports/trivy-image.json",
        "--exit-code", "0",
        $ImageName
      ))
    if ($trivyExitCode -ne 0) {
      throw "Trivy failed to complete the image scan."
    }

    $trivyResults = Get-Content $jsonReport -Raw | ConvertFrom-Json
    $blockingVulnerabilities = @($trivyResults.Results | ForEach-Object {
      $_.Vulnerabilities | Where-Object { $_.Severity -in @("HIGH", "CRITICAL") }
    })

    if ($blockingVulnerabilities.Count -gt 0) {
      $trivyTableContainerName = "todo-app-trivy-$([Guid]::NewGuid().ToString('N'))"
      $trivyTableExitCode = Invoke-DockerWithTimeout `
        -ContainerName $trivyTableContainerName `
        -TimeoutSeconds 600 `
        -Arguments ($trivyRunPrefix + @(
          "--name", $trivyTableContainerName
        ) + $trivyScanArgs + @(
          "--format", "table",
          "--output", "/reports/trivy-image.txt",
          "--exit-code", "0",
          $ImageName
        ))
      if ($trivyTableExitCode -ne 0 -or -not (Test-Path $tableReport)) {
        Write-Warning "Trivy found vulnerabilities, but the table report could not be generated."
      }
      throw "Trivy found high or critical image vulnerabilities."
    }
  }
}

if (Should-Run "zap") {
  Invoke-ScanStep "DAST scan (OWASP ZAP)" {
    & (Join-Path $PSScriptRoot "zap-baseline.ps1") -TargetUrl $TargetUrl -TimeoutSeconds $ZapTimeoutSeconds
  }
}

if ($Failures.Count -gt 0) {
  $message = "DevSecOps scan failed:`n" + ($Failures -join "`n")
  & (Join-Path $PSScriptRoot "notify-telegram.ps1") -Message $message
  throw ($Failures -join "; ")
}

Write-Host ""
Write-Host "All requested security scans completed successfully."
