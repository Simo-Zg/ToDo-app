# /logs Prompt

Intent: show recent GitLab job logs.

If the user provides a pipeline id, pass `-PipelineId <id>`. If the user provides a job name, pass `-JobName <name>`. Otherwise show the latest job logs for the latest pipeline.

Run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "D:\Projects\AI-Agent\scripts\gitlab-control.ps1" -Action logs -Tail 120
```

Response:

- Show the job name and job id.
- Show only the relevant tail output.
- If logs indicate a security failure, mention the report directory under `reports/`.
