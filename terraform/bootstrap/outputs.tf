output "state_bucket_name" {
  description = "Copy this into envs/prod/backend-config when you run terraform init there."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  value = aws_s3_bucket.terraform_state.arn
}

output "lock_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  value = data.aws_region.current.name
}

output "backend_config_example" {
  description = "Values for terraform init -backend-config=... in envs/prod."
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    key            = "prod/terraform.tfstate"
    region         = data.aws_region.current.name
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    encrypt        = true
  }
}
