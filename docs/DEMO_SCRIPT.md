# Final Demonstration Script

## 1. Start the local stack

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install.ps1
docker compose up --build
```

Show:

- `http://127.0.0.1:5000`
- `http://127.0.0.1:5000/health`

## 2. Install OpenClaw prompts

```powershell
powershell -ExecutionPolicy Bypass -File scripts\openclaw-install-prompts.ps1
```

Show the prompt files in:

```text
~/.openclaw/workspace/devsecops-prompts
```

## 3. Telegram commands

Run from Telegram:

```text
/start
/help
/status
/run_pipeline main
/scan main
/logs
/deploy staging main
```

Repeat one command from Slack and one from Discord to prove that the same prompt router is active.

## 4. GitLab evidence

Show:

- created pipeline
- security jobs
- artifacts under `reports/`
- local runner in `C:\Gitlab-Runner`

## 5. ZAP evidence

Show:

- ZAP installed on Windows
- `reports/zap/zap-*.html`
- DAST job result in GitLab

## 6. Deployment evidence

Show:

- `docker ps`
- `todo-app`
- `todo-mongodb`
- app health status
- Telegram deployment notification
