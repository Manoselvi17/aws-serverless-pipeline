############################################
# S3 bucket - where files get uploaded
############################################
resource "aws_s3_bucket" "raw_data" {
  bucket = "${var.project_name}-raw-data-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-raw-data"
  }
}

resource "aws_s3_bucket_public_access_block" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# EventBridge needs to be enabled on the bucket to send
# notifications when new objects are uploaded
resource "aws_s3_bucket_notification" "raw_data" {
  bucket      = aws_s3_bucket.raw_data.id
  eventbridge = true
}

data "aws_caller_identity" "current" {}
