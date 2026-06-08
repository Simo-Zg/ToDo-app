# Shared Command Map

These commands are valid on Telegram, Slack, and Discord. A channel may deliver them as plain text or as a bot mention followed by the command; normalize both to the same command.

| Command | Purpose | Script |
| --- | --- | --- |
| `/start` | Welcome and show system scope | `commands/start.md` |
| `/help` | Show available commands | `commands/help.md` |
| `/status [pipeline_id]` | Show latest or selected pipeline status | `scripts/gitlab-control.ps1 -Action status` |
| `/run_pipeline [ref]` | Start CI/CD pipeline | `scripts/gitlab-control.ps1 -Action run` |
| `/stop_pipeline [pipeline_id]` | Cancel latest or selected pipeline | `scripts/gitlab-control.ps1 -Action stop` |
| `/retry_pipeline [pipeline_id]` | Retry latest or selected pipeline | `scripts/gitlab-control.ps1 -Action retry` |
| `/scan [ref]` | Start security pipeline with ZAP enabled | `scripts/gitlab-control.ps1 -Action scan` |
| `/deploy [staging|production] [ref]` | Start deploy pipeline | `scripts/gitlab-control.ps1 -Action deploy` |
| `/logs [pipeline_id] [job_name]` | Show recent job logs | `scripts/gitlab-control.ps1 -Action logs` |

## Script Invocation Format

Use PowerShell from Windows or WSL:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "D:\Projects\AI-Agent\scripts\gitlab-control.ps1" -Action status
```

When a command includes a pipeline id, pass `-PipelineId`. When it includes a branch/ref, pass `-Ref`. When it includes a job name, pass `-JobName`. When it includes a deployment environment, pass `-DeployEnv`.
