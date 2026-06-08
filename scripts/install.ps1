[CmdletBinding()]
param(
  [switch]$ForceEnv
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $ProjectRoot

function Assert-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' was not found in PATH."
  }
}

function New-HexSecret {
  param([int]$Bytes = 32)
  $buffer = New-Object byte[] $Bytes
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($buffer)
  return (($buffer | ForEach-Object { $_.ToString("x2") }) -join "")
}

Assert-Command node
Assert-Command npm
Assert-Command docker

if ((-not (Test-Path ".env")) -or $ForceEnv) {
  Copy-Item ".env.example" ".env" -Force
  $envText = Get-Content ".env" -Raw
  $envText = $envText -replace "AES_KEY=.*", "AES_KEY=$(New-HexSecret -Bytes 32)"
  $envText = $envText -replace "JWT_SECRET=.*", "JWT_SECRET=$(New-HexSecret -Bytes 32)"
  $envText = $envText -replace "JWT_REFRESH_SECRET=.*", "JWT_REFRESH_SECRET=$(New-HexSecret -Bytes 32)"
  $envText = $envText -replace "SECRET_PASSWORD=.*", "SECRET_PASSWORD=$(New-HexSecret -Bytes 16)"
  Set-Content ".env" $envText
  Write-Host "Created .env with local development secrets."
} else {
  Write-Host ".env already exists. Use -ForceEnv to regenerate it."
}

npm install

Write-Host ""
Write-Host "Installation complete."
Write-Host "Run: docker compose up --build"
Write-Host "App URL: http://127.0.0.1:5000"
