############################################
# SNS topic - where alerts get published
############################################
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

############################################
# Alarm: if anything lands in the DLQ, something
# failed and needs a look
############################################
resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  alarm_name          = "${var.project_name}-dlq-has-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 1
  metric_name          = "ApproximateNumberOfMessagesVisible"
  namespace            = "AWS/SQS"
  period               = 300
  statistic            = "Maximum"
  threshold            = 0
  alarm_description    = "Triggers when a message lands in the Dead-Letter Queue - means a file failed processing"
  alarm_actions        = [aws_sns_topic.alerts.arn]
  treat_missing_data    = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }
}

############################################
# Alarm: Lambda errors
############################################
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 1
  metric_name          = "Errors"
  namespace            = "AWS/Lambda"
  period               = 300
  statistic            = "Sum"
  threshold            = 0
  alarm_description    = "Triggers when the Lambda function throws an error"
  alarm_actions        = [aws_sns_topic.alerts.arn]
  treat_missing_data    = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.processor.function_name
  }
}
