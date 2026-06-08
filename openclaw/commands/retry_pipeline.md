# /retry_pipeline Prompt

Intent: retry failed or canceled jobs in a GitLab pipeline.

If the user provides a pipeline id, pass `-PipelineId <id>`. Otherwise retry the latest pipeline on the configured ref.

Run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "D:\Projects\AI-Agent\scripts\gitlab-control.ps1" -Action retry
```

Response:

- Confirm the retry request.
- Show new pipeline status and URL.
- Suggest `/logs <pipeline_id>` if the retry fails.
