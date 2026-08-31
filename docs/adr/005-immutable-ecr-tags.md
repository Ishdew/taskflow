# ADR-005: Immutable ECR tags and SHA deploys


## Context

ECR can use mutable or immutable image tags. Mutable `latest` is easy for demos but dangerous: you cannot tell which bytes a tag pointed at last week, and overwrites hide history.

Our Terraform module defaults the repository to **IMMUTABLE**.

## Decision

- CI builds once and pushes **`${CI_COMMIT_SHORT_SHA}`** only.
- Deploy registers a new ECS task definition that references that tag.
- We do **not** push `:latest` from the pipeline.

## Why

- Every deploy is traceable to a git commit.
- Retries and rollbacks use an exact previous tag that still exists.
- Matches the repository’s immutability setting (pushing `latest` twice already failed CI once — that failure confirmed the policy works).

## Trade-offs

- First-time bootstrap still needs *some* image tag before the service can start; use a one-off unique tag or the first SHA, not a recycled `latest`.
- Humans must pass the tag through dotenv artifacts in CI.

## Consequences

`ecs_deploy` must rewrite the container image on the task definition. Force-new-deployment alone is not enough if the task still points at an old immutable tag.
