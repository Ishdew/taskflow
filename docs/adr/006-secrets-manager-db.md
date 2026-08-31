# ADR-006: Database credentials in Secrets Manager


## Context

The app needs a PostgreSQL username and password. Putting them in Terraform variables, environment files in git, or plain ECS `environment` blocks risks leaks in logs, state, and screenshots.

## Decision

Terraform creates an RDS instance and a random password, stores the credentials in **AWS Secrets Manager**, and grants the ECS **task execution** role permission to read that secret. The task definition maps secret keys into container environment variables at start-up.

## Why

- Password never appears in the repository.
- Access is IAM-controlled and auditable.
- Rotation-friendly layout (even if we do not automate rotation yet).

## Trade-offs

- Local Docker Compose still uses a documented local password from `.env.example` (dev only).
- Debugging “cannot read secret” requires IAM and Secrets Manager checks, not just app logs.

## Consequences

Gitleaks, `.gitignore`, and CI secret scanning stay focused on keeping real credentials out of commits. The runbook points operators at the secret name, not at a password value.
