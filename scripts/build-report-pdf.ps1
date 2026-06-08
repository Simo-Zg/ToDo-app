[CmdletBinding()]
param(
  [string]$MarkdownPath,
  [string]$OutputPath
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if ([string]::IsNullOrWhiteSpace($MarkdownPath)) {
  $MarkdownPath = Join-Path $ProjectRoot "docs\FINAL_REPORT.md"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $ProjectRoot "docs\FINAL_REPORT.pdf"
}

$htmlPath = Join-Path $ProjectRoot "docs\FINAL_REPORT.html"

$markdown = Get-Content $MarkdownPath -Raw
$encoded = [System.Net.WebUtility]::HtmlEncode($markdown)
$html = @"
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Final Report - DevSecOps AI Agent</title>
  <style>
    body { font-family: Segoe UI, Arial, sans-serif; line-height: 1.45; max-width: 920px; margin: 40px auto; color: #17202a; }
    code { background: #eef1f4; padding: 2px 4px; border-radius: 4px; }
    h1, h2, h3 { color: #0f3b57; }
  </style>
</head>
<body>
  <pre style="white-space: pre-wrap; font-family: Segoe UI, Arial, sans-serif;">$encoded</pre>
</body>
</html>
"@

Set-Content $htmlPath $html

$programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
$edge = @(
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "$programFilesX86\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $edge) {
  throw "Microsoft Edge was not found. The HTML report was created at $htmlPath. Install Edge or use another Markdown-to-PDF tool."
}

$edgeProfile = Join-Path $env:TEMP "todo-devsecops-edge-profile"
New-Item -ItemType Directory -Force -Path $edgeProfile | Out-Null

& $edge --headless=new --disable-gpu --no-first-run --user-data-dir="$edgeProfile" --print-to-pdf="$OutputPath" "file:///$($htmlPath -replace '\\','/')"

if ($LASTEXITCODE -ne 0 -and (-not (Test-Path $OutputPath))) {
  throw "PDF generation failed with exit code $LASTEXITCODE"
}

Write-Host "PDF report generated: $OutputPath"
