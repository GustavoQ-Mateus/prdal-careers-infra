variable "imagens_executores" {
  type    = map(string)
  default = {}
  validation {
    condition = length(var.imagens_executores) == 0 || (
      toset(keys(var.imagens_executores)) == toset(["ai-service", "lambda-enviar-lembrete", "batch-migrar-arquivos-s3", "batch-reprocessar-keywords"]) &&
      alltrue([for nome, imagem in var.imagens_executores : can(regex("^765656213653\\.dkr\\.ecr\\.us-east-1\\.amazonaws\\.com/prdal-demo/${nome}@sha256:[a-f0-9]{64}$", imagem))])
    )
    error_message = "Informe as quatro imagens do ECR pessoal por digest, ou um mapa vazio para preparar a base."
  }
}

variable "lambda_segredos_por_arn" {
  type    = bool
  default = false
}

variable "ai_model" {
  type    = string
  default = "claude-sonnet-5"
}

variable "ai_service_url" {
  type    = string
  default = null
}

variable "arquivos_efs" {
  type = object({
    id                = string
    access_point      = string
    security_group_id = string
    arn               = string
  })
  default = null
}

locals {
  habilitar_executores = var.habilitar_base && length(var.imagens_executores) > 0
  passos = {
    geracao-rascunho  = "LAMBDA_GERACAO_RASCUNHO"
    geracao-verificar = "LAMBDA_GERACAO_VERIFICAR"
    geracao-reparar   = "LAMBDA_GERACAO_REPARAR"
    geracao-montar    = "LAMBDA_GERACAO_MONTAR"
    keywords          = "LAMBDA_KEYWORDS"
  }
}

resource "aws_sns_topic" "alertas" {
  count = var.habilitar_base ? 1 : 0
  name  = "prdal-demo-alertas"
}

resource "aws_sns_topic_subscription" "alertas" {
  count     = var.habilitar_base ? 1 : 0
  topic_arn = aws_sns_topic.alertas[0].arn
  protocol  = "email"
  endpoint  = var.email_orcamento
}

resource "aws_secretsmanager_secret" "database_url_batch" {
  count                   = var.habilitar_base ? 1 : 0
  name                    = "prdal-demo/BATCH_DATABASE_URL"
  recovery_window_in_days = 0
}

module "passos" {
  for_each = local.habilitar_executores ? local.passos : {}
  source   = "../../modules/lambda"
  nome     = "prdal-demo-${each.key}"
  imagem   = var.imagens_executores["ai-service"]
  comando  = ["app.lambda_handler.handler"]
  ambiente = {
    AI_MODEL          = var.ai_model
    AI_MAX_TOKENS     = "16000"
    AI_MAX_RETRIES    = "2"
    AI_TIMEOUT_PISO_S = "5"
    AI_TIMEOUT_TETO_S = "120"
    PRDAL_AMBIENTE    = "producao"
    HF_HOME           = "/tmp/huggingface"
  }
  segredos_arns      = { ANTHROPIC_API_KEY = module.segredos[0].arns.ANTHROPIC_API_KEY }
  topico_alertas_arn = aws_sns_topic.alertas[0].arn
}

module "lembrete" {
  count              = local.habilitar_executores ? 1 : 0
  source             = "../../modules/lambda"
  nome               = "prdal-demo-enviar-lembrete"
  imagem             = var.imagens_executores["lambda-enviar-lembrete"]
  comando            = ["dist/lembrete.handler"]
  timeout            = 30
  memoria            = 256
  ambiente           = { REMETENTE_MODO = "log" }
  topico_alertas_arn = aws_sns_topic.alertas[0].arn
}

module "scheduler" {
  count      = local.habilitar_executores ? 1 : 0
  source     = "../../modules/scheduler"
  nome       = "prdal-demo"
  lambda_arn = module.lembrete[0].arn
}

module "batch" {
  count                   = local.habilitar_executores ? 1 : 0
  source                  = "../../modules/batch"
  nome                    = "prdal-demo"
  vpc_id                  = module.network[0].vpc_id
  subnets                 = module.network[0].subnets_publicas
  banco_security_group_id = module.rds[0].security_group_id
  jobs = {
    batch-migrar-arquivos-s3 = {
      imagem = var.imagens_executores["batch-migrar-arquivos-s3"]
      ambiente = {
        AWS_REGION          = "us-east-1"
        S3_BUCKET           = module.artefatos[0].bucket
        ARQUIVOS_LOCAIS_DIR = "/app/storage"
      }
      segredos_arns    = { DATABASE_URL = aws_secretsmanager_secret.database_url_batch[0].arn }
      efs_id           = try(var.arquivos_efs.id, null)
      efs_access_point = try(var.arquivos_efs.access_point, null)
      politica_tarefa = jsonencode({
        Version = "2012-10-17"
        Statement = concat([{
          Effect = "Allow", Action = ["s3:PutObject", "s3:GetObject"], Resource = "arn:aws:s3:::${module.artefatos[0].bucket}/*"
          }, {
          Effect = "Allow", Action = ["s3:ListBucket"], Resource = "arn:aws:s3:::${module.artefatos[0].bucket}"
          }], var.arquivos_efs == null ? [] : [{
          Effect    = "Allow", Action = ["elasticfilesystem:ClientMount"], Resource = var.arquivos_efs.arn
          Condition = { StringEquals = { "elasticfilesystem:AccessPointArn" = "arn:aws:elasticfilesystem:us-east-1:765656213653:access-point/${var.arquivos_efs.access_point}" } }
        }])
      })
    }
    batch-reprocessar-keywords = {
      imagem = var.imagens_executores["batch-reprocessar-keywords"]
      ambiente = {
        AWS_REGION         = "us-east-1"
        AI_SERVICE_URL     = coalesce(var.ai_service_url, "http://ai-service:8000")
        LOTES_MODO         = "anthropic"
        ANTHROPIC_BASE_URL = "https://api.anthropic.com"
      }
      segredos_arns = {
        DATABASE_URL      = aws_secretsmanager_secret.database_url_batch[0].arn
        SERVICE_TOKEN     = module.segredos[0].arns.SERVICE_TOKEN
        ANTHROPIC_API_KEY = module.segredos[0].arns.ANTHROPIC_API_KEY
      }
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "arquivos_batch" {
  count                        = local.habilitar_executores && var.arquivos_efs != null ? 1 : 0
  security_group_id            = var.arquivos_efs.security_group_id
  referenced_security_group_id = module.batch[0].security_group_id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}

resource "terraform_data" "requisitos_executores" {
  count = local.habilitar_executores ? 1 : 0
  lifecycle {
    precondition {
      condition     = var.lambda_segredos_por_arn
      error_message = "A imagem do ai-service precisa carregar ANTHROPIC_API_KEY_ARN em runtime antes de habilitar as Lambdas."
    }
    precondition {
      condition     = var.ai_service_url != null && var.arquivos_efs != null
      error_message = "Batch exige URL interna do ai-service e EFS com os arquivos legados; o volume local do compose nao existe no Fargate."
    }
  }
}

output "ambiente_worker_executores" {
  value = local.habilitar_executores ? merge({
    for passo, variavel in local.passos : variavel => module.passos[passo].nome
    }, {
    EXECUTOR_MODO       = "lambda"
    AI_STEP_TIMEOUT_MS  = "120000"
    AGENDADOR_MODO      = "eventbridge"
    LEMBRETE_LAMBDA_ARN = module.lembrete[0].arn
    SCHEDULER_ROLE_ARN  = module.scheduler[0].papel_arn
  }) : null
}

output "politica_worker_executores" {
  value = local.habilitar_executores ? jsonencode({
    Version = "2012-10-17"
    Statement = concat(jsondecode(module.scheduler[0].politica_worker).Statement, [{
      Effect = "Allow", Action = ["lambda:InvokeFunction"], Resource = [for passo in module.passos : passo.arn]
    }])
  }) : null
}

output "batch_fila_arn" { value = local.habilitar_executores ? module.batch[0].fila_arn : null }
output "batch_jobs_arns" { value = local.habilitar_executores ? module.batch[0].jobs_arns : null }
output "batch_database_url_arn" { value = var.habilitar_base ? aws_secretsmanager_secret.database_url_batch[0].arn : null }
