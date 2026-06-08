[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Url,

  [int]$TimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)

while ((Get-Date) -lt $deadline) {
  try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
    if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
      Write-Host "HTTP target is reachable: $Url"
      exit 0
    }
  } catch {
    Start-Sleep -Seconds 3
  }
}

throw "Timed out waiting for $Url"
