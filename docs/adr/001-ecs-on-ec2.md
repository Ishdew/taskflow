# ADR-001: ECS on EC2 instead of Fargate


## Context

We needed somewhere to run the TaskFlow container on AWS. Two common options are **ECS on Fargate** (serverless containers) and **ECS on EC2** (containers on instances we manage).

The assignment also asks for **Ansible** to configure hosts, and for **vertical scaling** of task CPU/memory. That points at a model where hosts exist and can be configured.

## Decision

Run TaskFlow on **ECS with an EC2 Auto Scaling Group** using the ECS-optimized Amazon Linux 2023 AMI.

## Why this is a good fit

- Ansible has real hosts to configure (Docker, ECS agent, CloudWatch agent).
- Vertical scaling changes the **task definition** size; EC2 capacity providers can still place those tasks as long as the instance is large enough (or the ASG grows).
- We keep a clear split: Terraform owns the ASG and IAM; Ansible owns packages and config files on the box.

## Trade-offs

- We must patch and harden instances (handled with `dnf-automatic` and the `common` role).
- EC2 + NAT costs a bit more operational attention than pure Fargate.
- Fargate would have been simpler if host configuration were not required.

## Consequences

Private subnets, SSM access, and security groups become part of the design. The runbook assumes SSM, not SSH bastions.
