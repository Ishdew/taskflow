# Architecture Decision Records

Short notes on the important choices behind TaskFlow.
Each ADR explains **context**, **decision**, **why**, and **trade-offs**.

| ADR | Title |
|---|---|
| [001](001-ecs-on-ec2.md) | ECS on EC2 instead of Fargate |
| [002](002-terraform-remote-state.md) | Terraform remote state with a bootstrap stack |
| [003](003-ansible-over-ssm.md) | Ansible over SSM (no bastion) |
| [004](004-vertical-scaling-lambda.md) | Vertical scaling with Lambda + SNS |
| [005](005-immutable-ecr-tags.md) | Immutable ECR tags and SHA deploys |
| [006](006-secrets-manager-db.md) | Database credentials in Secrets Manager |
