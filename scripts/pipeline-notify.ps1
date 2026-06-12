$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "load-env.ps1")

$pipelineId = $env:CI_PIPELINE_ID
$ref = $env:CI_COMMIT_REF_NAME
$url = $env:CI_PIPELINE_URL

$message = "Pipeline $pipelineId reached notify stage. Ref: $ref. URL: $url"

& (Join-Path $PSScriptRoot "notify-telegram.ps1") -Message $message
