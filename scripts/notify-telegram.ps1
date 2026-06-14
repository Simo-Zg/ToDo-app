[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Message,

  [string]$BotToken = $env:TELEGRAM_BOT_TOKEN,
  [string]$ChatId = $env:TELEGRAM_CHAT_ID
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "load-env.ps1")

if ([string]::IsNullOrWhiteSpace($BotToken)) {
  $BotToken = $env:TELEGRAM_BOT_TOKEN
}

if ([string]::IsNullOrWhiteSpace($ChatId)) {
  $ChatId = $env:TELEGRAM_CHAT_ID
}

if ([string]::IsNullOrWhiteSpace($BotToken) -or [string]::IsNullOrWhiteSpace($ChatId)) {
  throw "TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID are required. Store them as masked GitLab CI/CD variables or expose them from HashiCorp Vault."
}

$uri = "https://api.telegram.org/bot$BotToken/sendMessage"
$body = @{
  chat_id = $ChatId
  text = $Message
  disable_web_page_preview = $true
}

Invoke-RestMethod -Method Post -Uri $uri -Body $body | Out-Null
Write-Host "Telegram notification sent."
