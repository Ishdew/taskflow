# ADR-004: Vertical scaling with Lambda + SNS


## Context

When a single task runs hot on CPU or memory, adding *more* identical tasks (horizontal scaling) is not always enough — especially on a small demo budget with one or two tasks. We also want an automatic way to give the *same* service a larger task size.

## Decision

CloudWatch alarms publish to SNS. A Python **Lambda** (`vertical_scaler`) reads the alarm direction, picks the next step on a fixed ladder (`256/512` → `512/1024` → `1024/2048`), registers a new task definition revision, and updates the ECS service.

Terraform **ignores** in-place changes to the live task definition size so the scaler and CI can move the service without the next `terraform apply` immediately fighting them.

## Why

- Matches the assignment’s vertical-scaling requirement cleanly.
- Keeps scaling logic in one small, testable function.
- Horizontal autoscaling remains an optional bonus on desired count.

## Trade-offs

- Task replacement causes a short rollout (mitigated by ALB health checks).
- The ladder is discrete; it is not continuous rightsizing.
- Operators must understand that Terraform is not the source of truth
  for the *current* CPU/memory after the Lambda has run.

## Consequences

Manual invoke with `{"direction":"up"}` is the evidence path. The runbook lists the cluster/service names and how to watch the rollout.
