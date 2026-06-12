# /scan Prompt

Intent: launch the security workflow from chat.

This command starts a GitLab pipeline with security flags:

- SAST with Semgrep
- SAST/quality analysis with SonarQube when `SONAR_TOKEN` is configured
- dependency scan with npm audit
- secret scan with Gitleaks
- Docker image scan with Trivy
- ZAP DAST enabled through `RUN_ZAP=true`

If the user provides a ref, pass `-Ref <ref>`.

Run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "D:\Projects\AI-Agent\scripts\gitlab-control.ps1" -Action scan
```

Response:

- Confirm scan pipeline creation.
- Show pipeline id, status, ref, and URL.
- Tell the user `/logs <pipeline_id>` can show scan output.
