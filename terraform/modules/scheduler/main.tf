variable "nome" { type = string }
variable "lambda_arn" { type = string }

data "aws_caller_identity" "atual" {}
data "aws_region" "atual" {}

locals {
  grupo_arn = "arn:aws:scheduler:${data.aws_region.atual.region}:${data.aws_caller_identity.atual.account_id}:schedule-group/default"
}

resource "aws_iam_role" "agendador" {
  name = "${var.nome}-scheduler"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "scheduler.amazonaws.com" }
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.atual.account_id }
        ArnEquals    = { "aws:SourceArn" = local.grupo_arn }
      }
    }]
  })
}

resource "aws_iam_role_policy" "invocar" {
  name = "invocar-lembrete"
  role = aws_iam_role.agendador.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = var.lambda_arn
    }]
  })
}

output "papel_arn" { value = aws_iam_role.agendador.arn }
output "politica_worker" {
  value = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["scheduler:CreateSchedule", "scheduler:UpdateSchedule", "scheduler:DeleteSchedule"]
      Resource = "arn:aws:scheduler:${data.aws_region.atual.region}:${data.aws_caller_identity.atual.account_id}:schedule/default/acao-*"
      }, {
      Effect    = "Allow"
      Action    = ["iam:PassRole"]
      Resource  = aws_iam_role.agendador.arn
      Condition = { StringEquals = { "iam:PassedToService" = "scheduler.amazonaws.com" } }
    }]
  })
}
