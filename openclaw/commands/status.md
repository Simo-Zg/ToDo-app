# /status Prompt

Intent: show GitLab pipeline status.

If the user provides a pipeline id, pass it as `-PipelineId`. Otherwise show the latest pipeline for the configured ref.

Run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "D:\Projects\AI-Agent\scripts\gitlab-control.ps1" -Action status
```

Response:

- Pipeline id
- Status
- Ref/SHA if returned
- GitLab URL
- If failed, suggest `/logs <pipeline_id>`.
