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
    $body = @{
      ref = $Ref
      variables = @(
        @{ key = "RUN_DEPLOY"; value = "true" },
        @{ key = "DEPLOY_ENV"; value = $DeployEnv }
      )
    }
    $pipeline = Invoke-GitLabJson -Method Post -Path "/pipeline" -Body $body
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
