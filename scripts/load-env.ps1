[CmdletBinding()]
param(
  [string]$EnvPath
)

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($EnvPath)) {
  $EnvPath = Join-Path $ProjectRoot ".env"
}

if (-not (Test-Path $EnvPath)) {
  return
}

foreach ($entry in (Get-Content $EnvPath)) {
  $line = $entry.Trim()
  if (-not $line -or $line.StartsWith("#") -or -not $line.Contains("=")) {
    continue
  }

  $name, $value = $line -split "=", 2
  $name = $name.Trim()
  $value = $value.Trim().Trim('"').Trim("'")

  if ($name -and -not [Environment]::GetEnvironmentVariable($name, "Process")) {
    [Environment]::SetEnvironmentVariable($name, $value, "Process")
  }
}
