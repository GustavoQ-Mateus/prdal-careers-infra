module "segredos" {
  count  = var.habilitar_base ? 1 : 0
  source = "../../modules/segredos"
  nome   = "prdal-demo"
}

output "segredos_arns" {
  value = var.habilitar_base ? module.segredos[0].arns : null
}

resource "aws_secretsmanager_secret" "database_url" {
  count                   = var.habilitar_base ? 1 : 0
  name                    = "prdal-demo/DATABASE_URL"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "database_url" {
  count         = var.habilitar_base ? 1 : 0
  secret_id     = aws_secretsmanager_secret.database_url[0].id
  secret_string = "postgresql://prdal:${module.rds[0].password}@${module.rds[0].endpoint}/prdal_careers?schema=public"
}

output "database_url_arn" {
  value = var.habilitar_base ? aws_secretsmanager_secret.database_url[0].arn : null
}
