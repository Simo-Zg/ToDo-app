# /run_pipeline Prompt

Intent: start a normal CI/CD pipeline.

If the user provides a ref, pass `-Ref <ref>`. Otherwise use `GITLAB_REF` or `main`.

Run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "D:\Projects\AI-Agent\scripts\gitlab-control.ps1" -Action run
```

Response:

- Confirm pipeline creation.
- Show pipeline id, status, ref, and URL.
- Tell the user `/status <pipeline_id>` can be used to monitor it.
