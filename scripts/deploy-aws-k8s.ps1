[CmdletBinding()]
param(
  [ValidateSet("staging", "production")]
  [string]$Environment = "staging",

  [string]$AwsRegion = $env:AWS_REGION,
  [string]$ClusterName = $env:AWS_EKS_CLUSTER_NAME,
  [string]$Namespace = $env:K8S_NAMESPACE,
  [string]$Image = $env:K8S_IMAGE,
  [string]$ServiceType = $env:K8S_SERVICE_TYPE,
  [switch]$RequireSecrets
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

function New-HexSecret {
  param([int]$Bytes = 32)
  $buffer = New-Object byte[] $Bytes
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $rng.GetBytes($buffer)
  } finally {
    $rng.Dispose()
  }
  return (($buffer | ForEach-Object { $_.ToString("x2") }) -join "")
}

function Get-SecretValue {
  param(
    [string]$Name,
    [string]$Fallback,
    [switch]$Required
  )

  $value = [Environment]::GetEnvironmentVariable($Name)
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = $Fallback
  }
  if ($Required -and [string]::IsNullOrWhiteSpace($value)) {
    throw "$Name is required for $Environment deployment."
  }
  return $value
}

Assert-Command aws
Assert-Command kubectl

if ([string]::IsNullOrWhiteSpace($AwsRegion)) {
  $AwsRegion = $env:AWS_DEFAULT_REGION
}
if ([string]::IsNullOrWhiteSpace($AwsRegion)) {
  throw "AWS_REGION or AWS_DEFAULT_REGION is required."
}
if ([string]::IsNullOrWhiteSpace($ClusterName)) {
  throw "AWS_EKS_CLUSTER_NAME is required."
}
if ([string]::IsNullOrWhiteSpace($Namespace)) {
  $Namespace = "todo-$Environment"
}
if ([string]::IsNullOrWhiteSpace($Image)) {
  $Image = $env:AWS_ECR_IMAGE
}
if ([string]::IsNullOrWhiteSpace($Image)) {
  throw "K8S_IMAGE or AWS_ECR_IMAGE is required."
}
if ([string]::IsNullOrWhiteSpace($ServiceType)) {
  $ServiceType = "ClusterIP"
}

$mongoDb = Get-SecretValue -Name "MONGO_DB" -Fallback "todo_devsecops"
$jwtSecret = Get-SecretValue -Name "JWT_SECRET" -Fallback (New-HexSecret -Bytes 32) -Required:$RequireSecrets
$jwtRefreshSecret = Get-SecretValue -Name "JWT_REFRESH_SECRET" -Fallback (New-HexSecret -Bytes 32) -Required:$RequireSecrets
$secretPassword = Get-SecretValue -Name "SECRET_PASSWORD" -Fallback (New-HexSecret -Bytes 16) -Required:$RequireSecrets
$aesKey = Get-SecretValue -Name "AES_KEY" -Fallback (New-HexSecret -Bytes 32) -Required:$RequireSecrets

Write-Host "Updating kubeconfig for EKS cluster '$ClusterName' in $AwsRegion"
& aws eks update-kubeconfig --name $ClusterName --region $AwsRegion
if ($LASTEXITCODE -ne 0) {
  throw "aws eks update-kubeconfig failed."
}

Write-Host "Ensuring namespace: $Namespace"
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
if ($LASTEXITCODE -ne 0) {
  throw "Unable to create/apply namespace '$Namespace'."
}

Write-Host "Applying ConfigMap and Secret"
kubectl -n $Namespace create configmap todo-app-config `
  --from-literal=PORT=5000 `
  --from-literal=NODE_ENV=$Environment `
  --from-literal=MONGO_HOST=mongodb-service `
  --from-literal=MONGO_PORT=27017 `
  --from-literal=MONGO_DB=$mongoDb `
  --from-literal=MONGO_DB_URI="mongodb://mongodb-service:27017/$mongoDb" `
  --dry-run=client -o yaml | kubectl apply -f -
if ($LASTEXITCODE -ne 0) {
  throw "Unable to apply todo-app-config."
}

kubectl -n $Namespace create secret generic todo-app-secrets `
  --from-literal=JWT_SECRET=$jwtSecret `
  --from-literal=JWT_REFRESH_SECRET=$jwtRefreshSecret `
  --from-literal=SECRET_PASSWORD=$secretPassword `
  --from-literal=AES_KEY=$aesKey `
  --dry-run=client -o yaml | kubectl apply -f -
if ($LASTEXITCODE -ne 0) {
  throw "Unable to apply todo-app-secrets."
}

Write-Host "Applying Kubernetes manifests"
kubectl -n $Namespace apply -f (Join-Path $ProjectRoot "k8s\aws\mongodb.yaml")
if ($LASTEXITCODE -ne 0) {
  throw "Unable to apply MongoDB manifest."
}
kubectl -n $Namespace apply -f (Join-Path $ProjectRoot "k8s\aws\todo-app.yaml")
if ($LASTEXITCODE -ne 0) {
  throw "Unable to apply Todo app manifest."
}

Write-Host "Setting app image: $Image"
kubectl -n $Namespace set image deployment/todo-app todo-app=$Image
if ($LASTEXITCODE -ne 0) {
  throw "Unable to set Todo app image."
}

if ($ServiceType -in @("ClusterIP", "NodePort", "LoadBalancer")) {
  kubectl -n $Namespace patch service todo-app-service -p "{`"spec`":{`"type`":`"$ServiceType`"}}"
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to patch service type to $ServiceType."
  }
} else {
  throw "Unsupported K8S_SERVICE_TYPE '$ServiceType'. Use ClusterIP, NodePort, or LoadBalancer."
}

Write-Host "Waiting for MongoDB and Todo app rollouts"
kubectl -n $Namespace rollout status deployment/mongodb --timeout=180s
if ($LASTEXITCODE -ne 0) {
  throw "MongoDB rollout failed."
}
kubectl -n $Namespace rollout status deployment/todo-app --timeout=180s
if ($LASTEXITCODE -ne 0) {
  throw "Todo app rollout failed."
}

Write-Host ""
Write-Host "Expected pod layout: 1 todo-app pod + 1 mongodb pod"
kubectl -n $Namespace get pods,svc -l app.kubernetes.io/part-of=todo-devsecops

& (Join-Path $PSScriptRoot "notify-telegram.ps1") -Message "AWS EKS deployment '$Environment' completed in namespace '$Namespace'. Image: $Image"

Write-Host "AWS EKS deployment completed: $Environment / $Namespace"
