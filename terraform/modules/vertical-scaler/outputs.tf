output "lambda_function_name" {
  value = aws_lambda_function.scaler.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.scaler.arn
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}

output "size_ladder" {
  value = var.size_ladder
}
