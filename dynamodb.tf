############################################
# DynamoDB - where processed rows get stored
############################################
resource "aws_dynamodb_table" "processed_data" {
  name         = "${var.project_name}-processed-data"
  billing_mode = "PAY_PER_REQUEST" # free tier: 25 RCU/WCU equivalent, no charge at this scale
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-processed-data"
  }
}
