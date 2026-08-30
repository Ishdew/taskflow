# Optional helper when you init Terraform outside CI.
# Usage: ./ci/write-backend-config.sh taskflow-tfstate-ACCOUNT_ID

set -euo pipefail

BUCKET="${1:?usage: $0 <state-bucket-name>}"
REGION="${AWS_DEFAULT_REGION:-ap-south-1}"
TABLE="${TF_LOCK_TABLE:-taskflow-terraform-locks}"
OUT="${2:-terraform/envs/prod/backend-config.hcl}"

cat > "$OUT" <<EOF
bucket         = "${BUCKET}"
key            = "prod/terraform.tfstate"
region         = "${REGION}"
dynamodb_table = "${TABLE}"
encrypt        = true
EOF

echo "Wrote ${OUT}"
