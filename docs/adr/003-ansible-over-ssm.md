# ADR-003: Ansible over SSM (no bastion, no SSH keys in git)


## Context

ECS hosts live in private subnets. Someone still has to install and configure Docker, the ECS agent, and the CloudWatch agent. Classic options are a bastion host + SSH keys, VPN, or AWS Systems Manager.

## Decision

Use the Ansible **`aws_ssm`** connection plugin. Inventory comes from the **`amazon.aws.aws_ec2`** plugin, filtered by tags `Project=taskflow` and `Role=ecs-host`.

## Why

- No bastion to patch or pay for.
- No SSH private keys in the repository or on laptops for day-to-day work.
- Same IAM instance profile Terraform already attaches for SSM.
- CI can run the same playbook with AWS keys from GitLab variables.

## Trade-offs

- Requires the SSM agent (present on AL2023) and working instance endpoints / networking.
- On Windows laptops, Ansible must run from WSL on a Linux filesystem so `ansible.cfg` is not ignored.

## Consequences

SSM Session Manager plugin is a prerequisite. The runbook documents the world-writable `/mnt/c` pitfall. Security groups remain the network firewall; we keep **firewalld stopped** so it does not fight Docker.
