variable "nome" {
  type = string
}

resource "random_password" "jwt" {
  length  = 48
  special = false
}

resource "random_password" "servico" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "jwt" {
  name                    = "${var.nome}/JWT_SECRET"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = random_password.jwt.result
}

resource "aws_secretsmanager_secret" "servico" {
  name                    = "${var.nome}/SERVICE_TOKEN"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "servico" {
  secret_id     = aws_secretsmanager_secret.servico.id
  secret_string = random_password.servico.result
}

resource "aws_secretsmanager_secret" "anthropic" {
  name                    = "${var.nome}/ANTHROPIC_API_KEY"
  recovery_window_in_days = 0
}

output "arns" {
  value = {
    JWT_SECRET        = aws_secretsmanager_secret.jwt.arn
    SERVICE_TOKEN     = aws_secretsmanager_secret.servico.arn
    ANTHROPIC_API_KEY = aws_secretsmanager_secret.anthropic.arn
  }
}
