# /deploy Prompt

Intent: deploy the Todo app through the GitLab deployment workflow.

Accepted environments:

- `staging` default
- `production`

If the user provides an environment, pass it as `-DeployEnv`. If the user provides a ref, pass it as `-Ref`.

Run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "D:\Projects\AI-Agent\scripts\gitlab-control.ps1" -Action deploy -DeployEnv staging
```

Response:

- Confirm deployment pipeline creation.
- Show pipeline id, target environment, status, and URL.
- For production, explicitly say production deploy was requested.
