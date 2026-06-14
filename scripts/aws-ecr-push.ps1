[CmdletBinding()]
param(
  [string]$AwsRegion = $env:AWS_REGION,
  [string]$AwsAccountId = $env:AWS_ACCOUNT_ID,
  [string]$RepositoryName = $env:AWS_ECR_REPOSITORY,
  [string]$ImageTag = $env:CI_COMMIT_SHORT_SHA,
  [string]$LocalImage = "todo-app",
  [string]$DotEnvPath
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $ProjectRoot
. (Join-Path $PSScriptRoot "load-env.ps1")

function Assert-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' was not found in PATH."
  }
}

Assert-Command aws
Assert-Command docker

if ([string]::IsNullOrWhiteSpace($AwsRegion)) {
  $AwsRegion = $env:AWS_DEFAULT_REGION
}
if ([string]::IsNullOrWhiteSpace($AwsRegion)) {
  throw "AWS_REGION or AWS_DEFAULT_REGION is required."
}

if ([string]::IsNullOrWhiteSpace($RepositoryName)) {
  $RepositoryName = "todo-app"
}
if ([string]::IsNullOrWhiteSpace($ImageTag)) {
  $ImageTag = "local"
}

if ([string]::IsNullOrWhiteSpace($AwsAccountId)) {
  $AwsAccountId = (& aws sts get-caller-identity --query Account --output text).Trim()
}
if ([string]::IsNullOrWhiteSpace($AwsAccountId)) {
  throw "AWS_ACCOUNT_ID is required or aws sts get-caller-identity must be available."
}

$registry = "$AwsAccountId.dkr.ecr.$AwsRegion.amazonaws.com"
$imageUri = "$registry/$RepositoryName`:$ImageTag"

Write-Host "Ensuring ECR repository exists: $RepositoryName"
& aws ecr describe-repositories --repository-names $RepositoryName --region $AwsRegion *> $null
if ($LASTEXITCODE -ne 0) {
  & aws ecr create-repository --repository-name $RepositoryName --region $AwsRegion | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to create ECR repository '$RepositoryName'."
  }
}

Write-Host "Logging Docker into ECR: $registry"
$password = & aws ecr get-login-password --region $AwsRegion
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($password)) {
  throw "Unable to get ECR login password."
}
$password | docker login --username AWS --password-stdin $registry
if ($LASTEXITCODE -ne 0) {
  throw "Docker login to ECR failed."
}

Write-Host "Building image: $LocalImage`:$ImageTag"
docker build -t "$LocalImage`:$ImageTag" .
if ($LASTEXITCODE -ne 0) {
  throw "Docker build failed."
}

docker tag "$LocalImage`:$ImageTag" $imageUri
if ($LASTEXITCODE -ne 0) {
  throw "Docker tag failed."
}

Write-Host "Pushing image: $imageUri"
docker push $imageUri
if ($LASTEXITCODE -ne 0) {
  throw "Docker push to ECR failed."
}

if ([string]::IsNullOrWhiteSpace($DotEnvPath)) {
  $DotEnvPath = Join-Path $ProjectRoot "reports\aws\deploy.env"
}

$dotEnvDir = Split-Path $DotEnvPath -Parent
New-Item -ItemType Directory -Force -Path $dotEnvDir | Out-Null
@(
  "AWS_ECR_IMAGE=$imageUri",
  "K8S_IMAGE=$imageUri",
  "AWS_ECR_REPOSITORY=$RepositoryName",
  "AWS_REGION=$AwsRegion",
  "AWS_ACCOUNT_ID=$AwsAccountId"
) | Set-Content -Path $DotEnvPath

Write-Host "ECR image pushed: $imageUri"
Write-Host "Dotenv artifact: $DotEnvPath"
