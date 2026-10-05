variable "nome" { type = string }
variable "imagem" { type = string }
variable "comando" { type = list(string) }
variable "ambiente" {
  type    = map(string)
  default = {}
}
variable "segredos_arns" {
  type    = map(string)
  default = {}
}
variable "memoria" {
  type    = number
  default = 1024
}
variable "timeout" {
  type    = number
  default = 120
}
variable "concorrencia" {
  type    = number
  default = -1
  validation {
    condition     = var.concorrencia == -1 || var.concorrencia >= 1
    error_message = "Use -1 para concorrencia compartilhada ou uma reserva positiva apos conferir a cota da conta."
  }
}
variable "topico_alertas_arn" { type = string }

resource "aws_cloudwatch_log_group" "funcao" {
  name              = "/aws/lambda/${var.nome}"
  retention_in_days = 7
}

resource "aws_iam_role" "funcao" {
  name = "${var.nome}-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "funcao" {
  name = "executar"
  role = aws_iam_role.funcao.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.funcao.arn}:*"
      }], length(var.segredos_arns) == 0 ? [] : [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = values(var.segredos_arns)
    }])
  })
}

resource "aws_lambda_function" "funcao" {
  function_name                  = var.nome
  package_type                   = "Image"
  image_uri                      = var.imagem
  role                           = aws_iam_role.funcao.arn
  architectures                  = ["x86_64"]
  memory_size                    = var.memoria
  timeout                        = var.timeout
  reserved_concurrent_executions = var.concorrencia
  image_config {
    command = var.comando
  }
  environment {
    variables = merge(var.ambiente, { for nome, arn in var.segredos_arns : "${nome}_ARN" => arn })
  }
  depends_on = [aws_iam_role_policy.funcao, aws_cloudwatch_log_group.funcao]
}

resource "aws_cloudwatch_metric_alarm" "funcao" {
  for_each            = toset(["Errors", "Throttles"])
  alarm_name          = "${var.nome}-${lower(each.key)}"
  namespace           = "AWS/Lambda"
  metric_name         = each.key
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = aws_lambda_function.funcao.function_name }
  alarm_actions       = [var.topico_alertas_arn]
}

output "arn" { value = aws_lambda_function.funcao.arn }
output "nome" { value = aws_lambda_function.funcao.function_name }
