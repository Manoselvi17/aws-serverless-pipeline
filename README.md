# Serverless Event-Driven Data Pipeline (AWS + Terraform)

An automated, event-driven pipeline: uploading a CSV file to S3 automatically
triggers processing, with results landing in DynamoDB and failures safely
captured in a Dead-Letter Queue instead of being silently lost.

## Architecture

```
User uploads CSV
       |
       v
  S3 bucket (raw data)
       |
       v
  EventBridge rule (watches for new uploads)
       |
       v
  Lambda function (parses CSV, writes rows)
       |
   ----+----
   |       |
   v       v
DynamoDB   SQS Dead-Letter Queue (on failure)
(success)       |
                v
          CloudWatch Alarm -> SNS (alerts you)
```

- **S3 bucket**: where raw CSV files get uploaded. EventBridge notifications
  are enabled directly on the bucket.
- **EventBridge rule**: listens for "Object Created" events on that bucket
  and invokes the Lambda function - this is what makes the pipeline
  event-driven rather than something you have to trigger manually.
- **Lambda function**: reads the uploaded CSV, parses each row, and writes
  it to DynamoDB with a generated ID and ingestion timestamp. If parsing
  fails, it raises an error rather than failing silently.
- **DynamoDB**: stores successfully processed rows. Pay-per-request billing,
  so there's no idle cost.
- **SQS Dead-Letter Queue**: if the Lambda function fails (bad file, bad
  data), the failed event lands here instead of being lost, so it can be
  investigated later.
- **CloudWatch alarms**: watch for any message landing in the DLQ, and any
  Lambda errors, publishing to an SNS topic.
- **IAM**: the Lambda's role only has permission to read from this specific
  S3 bucket, write to this specific DynamoDB table, and send to this
  specific queue - least privilege, not broad access.

## Design Tradeoffs

- **EventBridge instead of a direct S3 -> Lambda trigger.** A direct trigger
  is simpler, but EventBridge is the pattern real event-driven systems use -
  it decouples the source from the consumer, and makes it easy to add more
  targets later (e.g. also notify a Slack channel) without touching the S3
  bucket's config.
- **Dead-Letter Queue instead of just logging errors.** Logs get lost in
  noise. A DLQ makes failures visible and re-processable - you could write
  a second Lambda that retries everything in the DLQ once the underlying
  issue is fixed.
- **DynamoDB instead of a relational database.** For this ingestion pattern
  (write-once, keyed by generated ID), DynamoDB's pay-per-request model
  means genuinely $0 cost at this scale, with no server to manage.

## Estimated Cost

Every component here is free-tier eligible at small scale:

| Resource | Free tier | Cost |
|---|---|---|
| S3 (storage + requests) | 5GB, 20k GET / 2k PUT per month | $0 |
| Lambda | 1M requests + 400,000 GB-seconds/month | $0 |
| DynamoDB (pay-per-request) | 25GB storage, generous free request tier | $0 |
| SQS | 1M requests/month | $0 |
| EventBridge | 1M events/month for custom rules | $0 |
| CloudWatch alarms + SNS | Free tier covers this scale | $0 |
| **Total** | | **$0/month** |

This is genuinely one of the cheapest architectures to experiment with -
there's no idle infrastructure like a NAT Gateway or Load Balancer running
in the background.

## Setup

1. Install Terraform >= 1.5 and configure AWS credentials (`aws configure`).
2. Initialize and apply:
   ```
   terraform init
   terraform plan
   terraform apply
   ```
3. Get your bucket name:
   ```
   terraform output upload_bucket_name
   ```
4. Upload the sample file to trigger the pipeline:
   ```
   aws s3 cp sample-data/expenses.csv s3://<your-bucket-name>/expenses.csv
   ```
5. Wait about 10-15 seconds, then check DynamoDB for the processed rows:
   ```
   aws dynamodb scan --table-name <your-table-name>
   ```

## Testing the Failure Path

Upload a deliberately broken file to see the Dead-Letter Queue in action:
```
echo "this is not a valid csv{{{" > broken.csv
aws s3 cp broken.csv s3://<your-bucket-name>/broken.csv
```
Check the DLQ shortly after - a failed message should appear, and the
CloudWatch alarm should trigger.

## Tear Down

```
terraform destroy
```
Since this architecture is free-tier at this scale, there's no urgency to
destroy for cost reasons - but it's still good practice to tear down
unused infrastructure.

## What I'd Add With More Time

- Athena + a curated S3 layer for SQL querying over processed data
- A second Lambda that automatically retries messages from the DLQ
- Data validation/schema checks before writing to DynamoDB
- Step Functions to orchestrate a multi-stage pipeline (validate -> enrich
  -> load) instead of a single Lambda doing everything
