variable "nome" {
  type = string
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.nome}-jobs-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "jobs" {
  name                       = "${var.nome}-jobs"
  visibility_timeout_seconds = 900
  sqs_managed_sse_enabled    = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

output "url" {
  value = aws_sqs_queue.jobs.url
}

output "arn" {
  value = aws_sqs_queue.jobs.arn
}
