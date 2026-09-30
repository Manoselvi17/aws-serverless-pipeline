output "upload_bucket_name" {
  description = "Upload a CSV file here to trigger processing"
  value       = aws_s3_bucket.raw_data.bucket
}

output "dynamodb_table_name" {
  description = "Where processed rows land"
  value       = aws_dynamodb_table.processed_data.name
}

output "dlq_url" {
  description = "Dead-Letter Queue for failed processing"
  value       = aws_sqs_queue.dlq.url
}

output "lambda_function_name" {
  value = aws_lambda_function.processor.function_name
}
