# After bootstrap, copy this file and fill in your bucket name:
#
#   cp backend-config.example.hcl backend-config.hcl
#   terraform init -backend-config=backend-config.hcl

bucket         = "taskflow-tfstate-467640460026"
key            = "prod/terraform.tfstate"
region         = "ap-south-1"
dynamodb_table = "taskflow-terraform-locks"
encrypt        = true
