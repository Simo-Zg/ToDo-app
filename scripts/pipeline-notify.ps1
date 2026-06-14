$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "load-env.ps1")

$pipelineId = $env:CI_PIPELINE_ID
$projectId = $env:GITLAB_PROJECT_ID
$baseUrl = $env:GITLAB_BASE_URL
$token = $env:GITLAB_API_TOKEN
$ref = $env:CI_COMMIT_REF_NAME
$url = $env:CI_PIPELINE_URL

if ([string]::IsNullOrWhiteSpace($baseUrl)) {
  $baseUrl = "https://gitlab.com"
}
if ([string]::IsNullOrWhiteSpace($projectId)) {
  $projectId = $env:CI_PROJECT_ID
}
if ([string]::IsNullOrWhiteSpace($projectId)) {
  throw "GITLAB_PROJECT_ID is required for pipeline notification."
}
if ([string]::IsNullOrWhiteSpace($token)) {
  throw "GITLAB_API_TOKEN is required for pipeline notification."
}
if ([string]::IsNullOrWhiteSpace($pipelineId)) {
  throw "CI_PIPELINE_ID is required for pipeline notification."
}

$encodedProjectId = [System.Uri]::EscapeDataString($projectId)
$headers = @{ "PRIVATE-TOKEN" = $token }
$jobsUri = "$baseUrl/api/v4/projects/$encodedProjectId/pipelines/$pipelineId/jobs?per_page=100"
$jobs = @(Invoke-RestMethod -Method Get -Uri $jobsUri -Headers $headers)
$relevantJobs = @($jobs | Where-Object { $_.name -ne "notify_pipeline" })
$failedJobs = @($relevantJobs | Where-Object { $_.status -in @("failed", "canceled") })

if ($failedJobs.Count -gt 0) {
  $failedNames = ($failedJobs | Sort-Object stage, name | ForEach-Object { "$($_.stage)/$($_.name): $($_.status)" }) -join "; "
  $message = "Pipeline $pipelineId failed. Ref: $ref. Failed jobs: $failedNames. URL: $url"
} else {
  $message = "Pipeline $pipelineId succeeded. Ref: $ref. URL: $url"
}

& (Join-Path $PSScriptRoot "notify-telegram.ps1") -Message $message
