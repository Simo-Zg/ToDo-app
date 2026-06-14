[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("run", "status", "stop", "retry", "logs", "deploy", "scan")]
  [string]$Action,

  [string]$PipelineId,
  [string]$JobName,
  [string]$Ref = $env:GITLAB_REF,
  [string]$DeployEnv = "staging",
  [int]$Tail = 120,
  [string]$BaseUrl = $env:GITLAB_BASE_URL,
  [string]$ProjectId = $env:GITLAB_PROJECT_ID,
  [string]$Token = $env:GITLAB_API_TOKEN
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "load-env.ps1")

if ([string]::IsNullOrWhiteSpace($BaseUrl)) { $BaseUrl = "https://gitlab.com" }
if ([string]::IsNullOrWhiteSpace($ProjectId)) { $ProjectId = $env:GITLAB_PROJECT_ID }
if ([string]::IsNullOrWhiteSpace($Token)) { $Token = $env:GITLAB_API_TOKEN }
if ([string]::IsNullOrWhiteSpace($Ref)) { $Ref = $env:GITLAB_REF }
if ([string]::IsNullOrWhiteSpace($Ref)) { $Ref = "main" }
if ([string]::IsNullOrWhiteSpace($ProjectId)) { throw "GITLAB_PROJECT_ID is missing." }
if ([string]::IsNullOrWhiteSpace($Token)) { throw "GITLAB_API_TOKEN is missing." }

$EncodedProjectId = [System.Uri]::EscapeDataString($ProjectId)
$Headers = @{ "PRIVATE-TOKEN" = $Token }

function Invoke-GitLabJson {
  param(
    [string]$Method,
    [string]$Path,
    [hashtable]$Body
  )

  $uri = "$BaseUrl/api/v4/projects/$EncodedProjectId$Path"
  if ($Body) {
    $jsonBody = $Body | ConvertTo-Json -Depth 8
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $Headers -ContentType "application/json" -Body $jsonBody
  }
  return Invoke-RestMethod -Method $Method -Uri $uri -Headers $Headers
}

function Get-LatestPipeline {
  $pipelines = Invoke-GitLabJson -Method Get -Path "/pipelines?ref=$Ref&per_page=1&order_by=id&sort=desc"
  if (-not $pipelines -or $pipelines.Count -eq 0) {
    throw "No pipeline found for ref '$Ref'."
  }
  return $pipelines[0]
}

function Resolve-PipelineId {
  if (-not [string]::IsNullOrWhiteSpace($PipelineId)) {
    return $PipelineId
  }
  return (Get-LatestPipeline).id
}

function Write-PipelineSummary {
  param($Pipeline)
  $webUrl = $Pipeline.web_url
  if (-not $webUrl) { $webUrl = "$BaseUrl/$ProjectId/-/pipelines/$($Pipeline.id)" }
  Write-Output "Pipeline #$($Pipeline.id)"
  Write-Output "Status: $($Pipeline.status)"
  Write-Output "Ref: $($Pipeline.ref)"
  Write-Output "SHA: $($Pipeline.sha)"
  Write-Output "URL: $webUrl"
}

function Get-PipelineJobs {
  param([string]$Id)
  return Invoke-GitLabJson -Method Get -Path "/pipelines/$Id/jobs?per_page=100"
}

function Wait-PipelineJob {
  param(
    [string]$Id,
    [string]$Name,
    [string[]]$Statuses,
    [int]$TimeoutSeconds = 1800
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $jobs = Get-PipelineJobs -Id $Id
    $job = $jobs | Where-Object { $_.name -eq $Name } | Sort-Object id -Descending | Select-Object -First 1
    if ($job -and $job.status -in $Statuses) {
      return $job
    }

    if ($job -and $job.status -in @("failed", "canceled", "skipped")) {
      throw "Job '$Name' reached terminal status '$($job.status)' before expected status '$($Statuses -join ", ")'."
    }

    Start-Sleep -Seconds 10
  }

  throw "Timed out waiting for job '$Name' to reach status '$($Statuses -join ", ")' in pipeline #$Id."
}

function Play-GitLabJob {
  param($Job)
  Write-Output "Playing job '$($Job.name)' (#$($Job.id))..."
  return Invoke-GitLabJson -Method Post -Path "/jobs/$($Job.id)/play"
}

function Wait-JobSuccess {
  param(
    [string]$Id,
    [string]$Name,
    [int]$TimeoutSeconds = 1800
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $jobs = Get-PipelineJobs -Id $Id
    $job = $jobs | Where-Object { $_.name -eq $Name } | Sort-Object id -Descending | Select-Object -First 1
    if ($job -and $job.status -eq "success") {
      return $job
    }
    if ($job -and $job.status -in @("failed", "canceled", "skipped")) {
      throw "Job '$Name' finished with status '$($job.status)'."
    }

    Start-Sleep -Seconds 15
  }

  throw "Timed out waiting for job '$Name' to finish successfully in pipeline #$Id."
}

switch ($Action) {
  "run" {
    $pipeline = Invoke-GitLabJson -Method Post -Path "/pipeline" -Body @{ ref = $Ref }
    Write-PipelineSummary $pipeline
  }

  "scan" {
    $pipeline = Invoke-GitLabJson -Method Post -Path "/pipeline" -Body @{ ref = $Ref }
    Write-PipelineSummary $pipeline
  }

  "deploy" {
    $target = $DeployEnv.ToLowerInvariant()
    if ($target -notin @("staging", "production")) {
      throw "DeployEnv must be 'staging' or 'production' for AWS EKS deployment."
    }

    $pipeline = Invoke-GitLabJson -Method Post -Path "/pipeline" -Body @{ ref = $Ref }
    Write-PipelineSummary $pipeline

    $packageJob = Wait-PipelineJob -Id $pipeline.id -Name "aws_ecr_package" -Statuses @("manual")
    Play-GitLabJob -Job $packageJob | Out-Null
    Wait-JobSuccess -Id $pipeline.id -Name "aws_ecr_package"

    $deployJobName = "deploy_aws_$target"
    $deployJob = Wait-PipelineJob -Id $pipeline.id -Name $deployJobName -Statuses @("manual")
    Play-GitLabJob -Job $deployJob | Out-Null
    Wait-JobSuccess -Id $pipeline.id -Name $deployJobName

    $pipeline = Invoke-GitLabJson -Method Get -Path "/pipelines/$($pipeline.id)"
    Write-Output ""
    Write-Output "AWS EKS deploy completed for '$target'."
    Write-PipelineSummary $pipeline
  }

  "status" {
    $id = Resolve-PipelineId
    $pipeline = Invoke-GitLabJson -Method Get -Path "/pipelines/$id"
    Write-PipelineSummary $pipeline
  }

  "stop" {
    $id = Resolve-PipelineId
    $pipeline = Invoke-GitLabJson -Method Post -Path "/pipelines/$id/cancel"
    Write-PipelineSummary $pipeline
  }

  "retry" {
    $id = Resolve-PipelineId
    $pipeline = Invoke-GitLabJson -Method Post -Path "/pipelines/$id/retry"
    Write-PipelineSummary $pipeline
  }

  "logs" {
    $id = Resolve-PipelineId
    $jobs = Invoke-GitLabJson -Method Get -Path "/pipelines/$id/jobs?per_page=100"
    if (-not $jobs -or $jobs.Count -eq 0) {
      throw "No jobs found for pipeline #$id."
    }

    if ($JobName) {
      $job = $jobs | Where-Object { $_.name -eq $JobName } | Select-Object -First 1
      if (-not $job) { throw "Job '$JobName' was not found in pipeline #$id." }
    } else {
      $job = $jobs | Sort-Object id -Descending | Select-Object -First 1
    }

    $traceUri = "$BaseUrl/api/v4/projects/$EncodedProjectId/jobs/$($job.id)/trace"
    $trace = (Invoke-WebRequest -Uri $traceUri -Headers $Headers -UseBasicParsing).Content
    $lines = $trace -split "`n"
    Write-Output "Logs for job '$($job.name)' (#$($job.id)), last $Tail lines:"
    $lines | Select-Object -Last $Tail
  }
}
