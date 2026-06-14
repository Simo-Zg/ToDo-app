[CmdletBinding()]
param(
  [string]$AwsRegion = $env:AWS_REGION,
  [string]$ClusterName = $env:AWS_EKS_CLUSTER_NAME,
  [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$TerraformRoot = Join-Path $ProjectRoot "terraform\aws-staging"
$ReportsRoot = Join-Path $ProjectRoot "reports\aws"
$InfraEnvPath = Join-Path $ReportsRoot "infra.env"

. (Join-Path $PSScriptRoot "load-env.ps1")

function Assert-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' was not found in PATH."
  }
}

Assert-Command terraform

if ([string]::IsNullOrWhiteSpace($AwsRegion)) {
  $AwsRegion = $env:AWS_DEFAULT_REGION
}
if ([string]::IsNullOrWhiteSpace($AwsRegion)) {
  throw "AWS_REGION or AWS_DEFAULT_REGION is required."
}
if ([string]::IsNullOrWhiteSpace($ClusterName)) {
  $ClusterName = "todo-devsecops-eks"
}

New-Item -ItemType Directory -Force -Path $ReportsRoot | Out-Null
@(
  "AWS_REGION=$AwsRegion",
  "AWS_EKS_CLUSTER_NAME=$ClusterName",
  "AWS_INFRA_STATUS=pending"
) | Set-Content -Path $InfraEnvPath -Encoding ascii

Set-Location $TerraformRoot

$initArgs = @("init", "-input=false", "-reconfigure")
if ($env:CI_API_V4_URL -and $env:CI_PROJECT_ID -and $env:CI_JOB_TOKEN) {
  $stateName = "aws-staging"
  $stateUrl = "$env:CI_API_V4_URL/projects/$env:CI_PROJECT_ID/terraform/state/$stateName"
  $initArgs += @(
    "-backend-config=address=$stateUrl",
    "-backend-config=lock_address=$stateUrl/lock",
    "-backend-config=unlock_address=$stateUrl/lock",
    "-backend-config=username=gitlab-ci-token",
    "-backend-config=password=$env:CI_JOB_TOKEN",
    "-backend-config=lock_method=POST",
    "-backend-config=unlock_method=DELETE",
    "-backend-config=retry_wait_min=5"
  )
} else {
  Write-Host "GitLab CI backend variables were not found. Terraform will use the local backend."
}

terraform @initArgs
if ($LASTEXITCODE -ne 0) {
  throw "terraform init failed."
}

$applyArgs = @(
  "apply",
  "-input=false",
  "-var", "aws_region=$AwsRegion",
  "-var", "cluster_name=$ClusterName"
)
if ($AutoApprove) {
  $applyArgs += "-auto-approve"
}

terraform @applyArgs
if ($LASTEXITCODE -ne 0) {
  throw "terraform apply failed."
}

@(
  "AWS_REGION=$AwsRegion",
  "AWS_EKS_CLUSTER_NAME=$ClusterName",
  "AWS_INFRA_STATUS=ready"
) | Set-Content -Path $InfraEnvPath -Encoding ascii

Write-Host "AWS staging infrastructure is ready."
Write-Host "AWS_EKS_CLUSTER_NAME=$ClusterName"
