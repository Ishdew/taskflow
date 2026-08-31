# TaskFlow runbook

Day-to-day operations for the deployed stack. Use when something looks wrong in production.

## Quick map

| Thing | Name / how to find it |
|---|---|
| Region | `ap-south-1` |
| ALB health | `http://<alb_dns>/health` |
| ECS cluster | `taskflow-prod-cluster` |
| ECS service | `taskflow-prod-service` |
| ECR repo | `taskflow` |
| Log group | `/ecs/taskflow-prod` |
| RDS instance | `taskflow-prod-postgres` |
| DB secret | Secrets Manager name like `taskflow-prod/db` |
| Vertical scaler | `terraform output -raw vertical_scaler_function_name` |

Get live values after apply:

```bash
cd terraform/envs/prod
terraform output
```

## How credentials are supplied

Nothing secret belongs in git.

| Secret | Where it lives | Who reads it |
|---|---|---|
| AWS keys for CI | GitLab CI/CD variables (Masked) | Pipeline jobs |
| AWS keys for laptop | `aws configure` / env vars | You, Terraform, Ansible |
| DB username/password | Secrets Manager (Terraform creates) | ECS task execution role |
| App config (`DB_HOST`, etc.) | ECS task definition environment | Container |

Locally, copy `.env.example` to `.env` if you want Compose overrides.
`.env` is gitignored.

## Deploy a new app version

Preferred: push to GitLab `main` and let the pipeline run.

1. Merge / push to `main`.
2. Wait for lint, security, test, build, plan.
3. Click **manual** `terraform_apply` only if infrastructure changed. If only the app changed, you can skip apply when the plan is empty — but the pipeline still expects the job graph; use the full path when in doubt.
4. `ansible_configure` re-applies host config (should be `changed=0` if nothing drifted).
5. `ecs_deploy` registers a task definition that points at the new ECR tag (`:CI_COMMIT_SHORT_SHA`) and waits for stability.
6. `smoke_test` curls the ALB `/health` until HTTP 200.

Manual deploy without waiting on Ansible (emergency):

```bash
ECR_URI=$(cd terraform/envs/prod && terraform output -raw ecr_repository_url)
TAG=<short-sha>   # must already exist in ECR

cd app
docker build -t "taskflow:${TAG}" .
aws ecr get-login-password --region ap-south-1 \
  | docker login --username AWS --password-stdin "${ECR_URI%/*}"
docker tag "taskflow:${TAG}" "${ECR_URI}:${TAG}"
docker push "${ECR_URI}:${TAG}"

# Then re-run the GitLab ecs_deploy job, or register a new task definition
# with this image the same way CI does.
```

ECR tags are **immutable**. Never push `:latest` twice. Always use a new SHA (or another unique tag).

## Rollback

Because tags are immutable, rollback means pointing ECS at an **older SHA that still exists** in ECR.

1. List recent images:

```bash
aws ecr describe-images --repository-name taskflow --region ap-south-1 \
  --query 'sort_by(imageDetails,& imagePushedAt)[-10:].[imageTags[0],imagePushedAt]' \
  --output table
```

2. **In GitLab (preferred):** open **CI/CD → Pipelines → Run pipeline**. Choose the **git commit** whose short SHA matches the image tag you want to restore (or check out that commit and push a no-op only if you must rebuild). Re-run / allow the pipeline through to **`ecs_deploy`** so it registers a task definition for that image. You do **not** need a fresh `terraform_apply` for an app-only rollback.

3. **From a laptop (emergency):** register a new task definition revision that keeps the current container config but sets `image` to `${ECR_URI}:<old-sha>`, then:

```bash
aws ecs update-service \
  --cluster taskflow-prod-cluster \
  --service taskflow-prod-service \
  --task-definition <family:revision-or-arn> \
  --force-new-deployment \
  --region ap-south-1
```

4. Confirm:

```bash
curl -s "http://$(cd terraform/envs/prod && terraform output -raw alb_dns_name)/health"
```

If the bad change was **infrastructure**, revert the git commit and run`terraform plan` / `apply` (or the manual apply job on that commit). Prefer git history over hand-editing AWS.

## Scaling

### Vertical (automatic)

Ladder (CPU / memory MiB): `256/512` → `512/1024` → `1024/2048`.

CloudWatch high alarms → SNS → Lambda registers the next size up and forces a new deployment. Low alarms step down. At the top or bottom of the ladder the Lambda logs and exits without changing anything.

**Smoke-test the Lambda** (when SNS/Lambda are healthy):

```bash
FN=$(cd terraform/envs/prod && terraform output -raw vertical_scaler_function_name)
aws lambda invoke --function-name "$FN" --payload '{"direction":"up"}' out.json
cat out.json
```

Watch the service:

```bash
aws ecs describe-services \
  --cluster taskflow-prod-cluster \
  --services taskflow-prod-service \
  --region ap-south-1 \
  --query 'services[0].{taskDef:taskDefinition,desired:desiredCount,running:runningCount}'
```

### Vertical fallback — if the Lambda or SNS misbehaves

Invoking the Lambda will not help if the function is broken, throttled, or SNS never delivers. Force a size change **outside** that path.

**Option A — Terraform (preferred when CI/laptop Terraform works)**

The ECS *service* ignores live `task_definition` drift so the scaler can work. After you change size in Terraform you must still point the service at the new revision.

```bash
cd terraform/envs/prod

# Example: jump straight to the top of the ladder
terraform apply \
  -var="task_cpu=1024" \
  -var="task_memory=2048"

NEW_TD=$(terraform output -raw ecs_task_definition_arn)
aws ecs update-service \
  --cluster taskflow-prod-cluster \
  --service taskflow-prod-service \
  --task-definition "$NEW_TD" \
  --force-new-deployment \
  --region ap-south-1
```

Same knobs work from GitLab: set CI variables `TF_VAR_task_cpu` / `TF_VAR_task_memory` (or pass `-var` in the apply job) and run the **manual** `terraform_apply`, then run / adapt `ecs_deploy` so the service uses the new task definition ARN.

**Option B — AWS CLI only (when Terraform is unavailable)**

1. Describe the current task definition JSON.
2. Bump `cpu` / `memory` (and the container equivalents if set).
3. Strip read-only fields (`taskDefinitionArn`, `revision`, `status`, …).
4. `aws ecs register-task-definition --cli-input-json …`
5. `aws ecs update-service --task-definition … --force-new-deployment`

That is the same idea the Lambda uses, without depending on SNS.

After any manual resize, put the intended size back into `terraform.tfvars` (or clear the emergency CI vars) so the next full apply does not surprise you.

### Horizontal

Application Auto Scaling keeps average CPU near ~60% by changing desired task count (typically 1–2). Check Terraform output `horizontal_scaling_enabled`.

To force more tasks temporarily:

```bash
aws ecs update-service \
  --cluster taskflow-prod-cluster \
  --service taskflow-prod-service \
  --desired-count 2 \
  --region ap-south-1
```

(Autoscaling may adjust this again; disable or raise the max if you need it to stick during an incident.)

## RDS backup and restore

Automatic backups are enabled in Terraform (`backup_retention_period`, Free Tier–safe at **1 day** in this project). That covers point-in-time recovery windows. For a named restore point before a risky change, take a **manual snapshot**.

### Trigger a manual snapshot

**CLI:**

```bash
aws rds create-db-snapshot \
  --db-instance-identifier taskflow-prod-postgres \
  --db-snapshot-identifier "taskflow-prod-manual-$(date +%Y%m%d-%H%M)" \
  --region ap-south-1

aws rds describe-db-snapshots \
  --db-instance-identifier taskflow-prod-postgres \
  --region ap-south-1 \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,Status,SnapshotCreateTime]' \
  --output table
```

Wait until `Status` is `available` before you rely on it.

**Console:** RDS → Databases → `taskflow-prod-postgres` → **Actions** → **Take snapshot**. Give it a clear name and wait for Available.

### Restore from a snapshot

Restoring always creates a **new** DB instance. The old one is unchanged until you either point TaskFlow at the new endpoint or rename instances so the app keeps using the same hostname.

**CLI — create a new instance from the snapshot:**

```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier taskflow-prod-postgres-restored \
  --db-snapshot-identifier <snapshot-id> \
  --db-instance-class db.t4g.micro \
  --region ap-south-1

# Wait until available
aws rds wait db-instance-available \
  --db-instance-identifier taskflow-prod-postgres-restored \
  --region ap-south-1

aws rds describe-db-instances \
  --db-instance-identifier taskflow-prod-postgres-restored \
  --query 'DBInstances[0].Endpoint' \
  --region ap-south-1
```

**Make TaskFlow use the restored database:**

1. Put the restored instance in the **same VPC / subnets / security group pattern** as the original (pass `--db-subnet-group-name` and `--vpc-security-group-ids` on restore if AWS did not inherit what you need — check the restore output).
2. Update the ECS task env `DB_HOST` (and secret if credentials differ) to the new endpoint, register a new task definition, and `update-service --force-new-deployment`.
3. Or, for a rename swap (short downtime, same hostname): stop the app / take the old instance out of service, rename `taskflow-prod-postgres` → `…-old`, rename `…-restored` → `taskflow-prod-postgres`, then start traffic again (the endpoint hostname follows the identifier).

**Console:** RDS → Snapshots → select snapshot → **Actions** → **Restore snapshot** → choose identifier / class / networking → restore. Then follow the steps above so ECS talks to the restored instance.

**Point-in-time recovery** (within the backup window), if you need a time rather than a named snapshot:

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier taskflow-prod-postgres \
  --target-db-instance-identifier taskflow-prod-postgres-pitr \
  --restore-time 2026-08-30T12:00:00Z \
  --region ap-south-1
```

After any restore that Terraform does not know about, either import the new instance into state or destroy the emergency DB when finished so the next `terraform apply` stays truthful.

## Common incidents

### ECS tasks stuck in `PENDING`

The scheduler accepted the task but it never reaches `RUNNING`.

1. Describe the task and read `stoppedReason` / `attachments` / agent messages:

```bash
aws ecs list-tasks --cluster taskflow-prod-cluster --desired-status RUNNING --region ap-south-1
aws ecs list-tasks --cluster taskflow-prod-cluster --desired-status STOPPED --region ap-south-1
aws ecs describe-tasks --cluster taskflow-prod-cluster --tasks <task-arn> --region ap-south-1
```

2. Typical causes on this stack:
   - **No EC2 capacity** — ASG has no warm instance, or the instance is too small for the current task size (especially after a vertical scale-up). Check ASG desired/in-service count and ECS container instance `registeredResources`.
   - **IAM** — instance profile missing ECS/SSM permissions; task execution role cannot pull from ECR or read the DB secret.
   - **Secrets Manager** — wrong secret ARN in the task definition, or missing `secretsmanager:GetSecretValue` on the execution role (tasks often sit pending / fail to start while injecting secrets).
   - **Image pull** — bad tag (immutable tag typo) or ECR permissions.

3. Host side: SSM into the instance (or CloudWatch agent logs) and confirm the ECS agent is running (`systemctl status ecs`).

### ALB returning `502`

The load balancer reached the target group but the target failed or closed the connection.

1. Target health:

```bash
aws elbv2 describe-target-health \
  --target-group-arn "$(aws elbv2 describe-target-groups \
    --names taskflow-prod-tg \
    --query 'TargetGroups[0].TargetGroupArn' --output text)" \
  --region ap-south-1
```

2. If targets are `unhealthy` or missing, check ECS running count and `/health` on the task. Deregistered targets during a bad deploy often show as 502 at the ALB.
3. App logs:

```bash
aws logs tail /ecs/taskflow-prod --since 30m --region ap-south-1
```

4. Classic host cause we already hit: **firewalld** cleared Docker iptables and broke published ports / DB access. The Ansible `common` role keeps firewalld **stopped**. Re-run `site.yml` if someone turned it back on.
5. Security groups: ALB → ECS dynamic host ports (`32768–65535` when using host port `0`).

### `/health` is not 200

Same checks as 502, plus readiness (DB) vs liveness. Hit `/health/liveness` and `/health/readiness` separately if the aggregate health is down.

### Database connection pool exhaustion

Symptoms: slow API, readiness failures, logs mentioning Hikari `Connection is not available` / timeout waiting for a connection.

1. Confirm RDS is healthy and not CPU/storage throttled (RDS console + CloudWatch).
2. Check how many tasks are running — horizontal scale × `DB_POOL_MAX_SIZE` (default **10** per task) must fit RDS `max_connections`.
3. Temporary relief: lower desired count, or lower pool size via task env `DB_POOL_MAX_SIZE` and redeploy; or scale the DB class (Terraform `db_instance_class`) if the instance is too small.
4. Look for connection leaks (long requests with `open-in-view` would hurt — we keep it `false` on purpose). Restart tasks after a spike to clear a wedged pool:

```bash
aws ecs update-service \
  --cluster taskflow-prod-cluster \
  --service taskflow-prod-service \
  --force-new-deployment \
  --region ap-south-1
```

### Database connection errors (auth / network)

- Confirm the secret still exists and the task execution role can read it.
- Confirm security groups: ECS tasks → RDS on 5432.
- Confirm RDS is `available`.

### Ansible cannot reach hosts

- Instances must be tagged `Project=taskflow` and `Role=ecs-host`.
- Instance profile must include SSM permissions (Terraform `iam` module).
- SSM agent online: EC2 → instance → Systems Manager.
- On Windows, run Ansible from **WSL** on a Linux path (not `/mnt/c`),because world-writable mounts make Ansible ignore `ansible.cfg`.

### Pipeline `trivy_image` fails

Upgrade the base image packages (`apk upgrade` in the Dockerfile) and bump vulnerable Maven dependencies. Do not disable the gate unless the finding is truly unfixed and you document an exception.

### Pipeline cannot overwrite an ECR tag

Expected with IMMUTABLE tags. Push a new commit (new SHA) or use a new unique tag. Do not switch the repo to MUTABLE just to reuse `latest`.

## Tear down

```bash
cd terraform/envs/prod
terraform destroy
```

Then remove bootstrap resources if you no longer need remote state (empty the S3 bucket first, then destroy bootstrap).

Empty ECR if destroy complains about images. Delete leftover ALB / ENIs only if Terraform reports leftovers after a failed destroy.

## Useful URLs

| What | Path |
|---|---|
| Health | `/health` |
| API | `/api/v1/tasks` |
| Swagger UI | `/swagger-ui.html` |
| OpenAPI JSON | `/v3/api-docs` |
