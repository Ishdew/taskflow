# ADR-002: Terraform remote state with a bootstrap stack

## Context

Terraform needs somewhere to store state so two people (or CI and a laptop) do not overwrite each other. Putting state on a laptop only is fragile. Putting the state bucket *inside* the same root module that creates the app creates a chicken-and-egg problem.

## Decision

Use a tiny **bootstrap** stack (local backend) that creates:

- an S3 bucket for state
- a DynamoDB table for state locking

The **prod** stack then uses that bucket/table as its remote backend.

## Why

- Bootstrap runs once per account.
- Prod state is shared, locked, and visible to GitLab CI.
- Modules stay reusable; only `envs/prod` knows account-specific values.

## Trade-offs

- Two `terraform apply` sequences instead of one.
- Bootstrap itself is not locked remotely (acceptable because it rarely
  changes and is tiny).

## Consequences

CI writes `backend-config.hcl` from variables (`TF_STATE_BUCKET`, `TF_LOCK_TABLE`). Real `*.tfvars` and `backend-config.hcl` stay out of git; examples are committed.
