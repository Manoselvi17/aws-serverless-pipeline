############################################
# SQS Dead-Letter Queue - where failed messages land
############################################
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-dlq"
  message_retention_seconds = 1209600 # 14 days - keep failed messages long enough to investigate

  tags = {
    Name = "${var.project_name}-dlq"
  }
}
