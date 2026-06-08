# /stop_pipeline Prompt

Intent: cancel a running GitLab pipeline.

If the user provides a pipeline id, pass `-PipelineId <id>`. Otherwise cancel the latest pipeline on the configured ref.

Run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "D:\Projects\AI-Agent\scripts\gitlab-control.ps1" -Action stop
```

Response:

- Confirm the cancellation request.
- Show resulting pipeline status and URL.
- If no pipeline is found, ask the user for the pipeline id.
