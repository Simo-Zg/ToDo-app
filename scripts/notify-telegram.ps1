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
  Write-Host "Telegram notification skipped: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is missing."
  exit 0
}

$uri = "https://api.telegram.org/bot$BotToken/sendMessage"
$body = @{
  chat_id = $ChatId
  text = $Message
  disable_web_page_preview = $true
}

Invoke-RestMethod -Method Post -Uri $uri -Body $body | Out-Null
Write-Host "Telegram notification sent."
