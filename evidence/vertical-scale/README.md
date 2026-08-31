# Vertical scaling evidence

## What happened

1. **Before:** service on `taskflow-prod-app:5` — **CPU 256 / memory 512**.
2. Forced CloudWatch alarm `taskflow-prod-ecs-cpu-high` to **ALARM**   (`aws cloudwatch set-alarm-state`). That publishes to SNS   `taskflow-prod-alerts`, which invokes the vertical scaler Lambda.
3. **After:** Lambda registered `taskflow-prod-app:6` — **CPU 512 / memory 1024** and updated the ECS service. Rollout was in progress when the after snapshot was taken (`runningCount` briefly 2 during drain).

Lambda result line (see `07-lambda-logs.txt`):

```text
{'status': 'scaled', 'direction': 'up',
 'from': {'cpu': 256, 'memory': 512},
 'to': {'cpu': 512, 'memory': 1024},
 'taskDefinition': '.../taskflow-prod-app:6'}
```

## Files in this folder

| File | Contents |
|---|---|
| `01-before-service.json` | ECS service pointing at revision 5 |
| `02-before-task-definition.json` | cpu=256, memory=512 |
| `03-before-alarms.json` | CPU/memory high alarms in OK |
| `04-alarm-in-ALARM.json` | `taskflow-prod-ecs-cpu-high` in ALARM |
| `05-after-service.json` | Service rolling onto revision 6 |
| `06-after-task-definition.json` | cpu=512, memory=1024 |
| `07-lambda-logs.txt` | SNS → Lambda scale-up log |

## How this was triggered

```powershell
& "$env:ProgramFiles\Amazon\AWSCLIV2\aws.exe" cloudwatch set-alarm-state `
  --alarm-name taskflow-prod-ecs-cpu-high `
  --state-value ALARM `
  --state-reason "Forced ALARM to demonstrate vertical scaling" `
  --region ap-south-1
```

Using `set-alarm-state` still walks the real path (alarm → SNS → Lambda → new task definition). It does not invent a fake ECS change.
