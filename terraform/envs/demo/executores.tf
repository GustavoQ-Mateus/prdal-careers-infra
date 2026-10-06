variable "imagens_servicos" {
  type    = map(string)
  default = {}
  validation {
    condition = length(var.imagens_servicos) == 0 || (
      toset(keys(var.imagens_servicos)) == toset(["api", "worker", "ai-service", "doc-service", "lambda-enviar-lembrete"]) &&
      alltrue([for nome, imagem in var.imagens_servicos : can(regex("^765656213653\\.dkr\\.ecr\\.us-east-1\\.amazonaws\\.com/prdal-demo/${nome}@sha256:[a-f0-9]{64}$", imagem))])
    )
    error_message = "Informe as cinco imagens do ECR pessoal por digest, ou um mapa vazio para preparar a base."
  }
}

variable "ai_model" {
  type    = string
  default = "anthropic/claude-sonnet-5"
}

locals {
  habilitar_executores = var.habilitar_base && length(var.imagens_servicos) > 0
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
  imagem   = var.imagens_servicos["ai-service"]
  comando  = ["app.lambda_handler.handler"]
  ambiente = {
    AI_MODEL           = var.ai_model
    ANTHROPIC_BASE_URL = "https://openrouter.ai/api"
    AI_MAX_TOKENS      = contains(["geracao-rascunho", "geracao-reparar"], each.key) ? "48000" : "16000"
    AI_MAX_RETRIES     = contains(["geracao-rascunho", "geracao-reparar", "geracao-verificar"], each.key) ? "0" : "2"
    AI_TIMEOUT_PISO_S  = "5"
    AI_TIMEOUT_TETO_S  = contains(["geracao-rascunho", "geracao-reparar", "geracao-verificar"], each.key) ? "540" : "120"
    PRDAL_AMBIENTE     = "producao"
    HF_HOME            = "/tmp/huggingface"
  }
  segredos_arns      = { ANTHROPIC_API_KEY_SECRET = module.segredos[0].arns.ANTHROPIC_API_KEY }
  timeout            = contains(["geracao-rascunho", "geracao-reparar", "geracao-verificar"], each.key) ? 600 : 120
  topico_alertas_arn = aws_sns_topic.alertas[0].arn
  depends_on         = [module.segredos]
}

data "aws_secretsmanager_secret_version" "doc_service_token" {
  count     = local.habilitar_executores ? 1 : 0
  secret_id = module.segredos[0].arns.SERVICE_TOKEN
}

module "doc_render" {
  count   = local.habilitar_executores ? 1 : 0
  source  = "../../modules/lambda"
  nome    = "prdal-demo-doc-render"
  imagem  = var.imagens_servicos["doc-service"]
  comando = ["doc-service::DocService.Lambda::FunctionHandlerAsync"]
  ambiente = {
    PRDAL_AMBIENTE = "producao"
    SERVICE_TOKEN  = data.aws_secretsmanager_secret_version.doc_service_token[0].secret_string
  }
  topico_alertas_arn = aws_sns_topic.alertas[0].arn
}

module "lembrete" {
  count              = local.habilitar_executores ? 1 : 0
  source             = "../../modules/lambda"
  nome               = "prdal-demo-enviar-lembrete"
  imagem             = var.imagens_servicos["lambda-enviar-lembrete"]
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

output "ambiente_worker_executores" {
  value = local.habilitar_executores ? merge({
    for passo, variavel in local.passos : variavel => module.passos[passo].nome
    }, {
    EXECUTOR_MODO                 = "lambda"
    AI_STEP_TIMEOUT_MS            = "620000"
    WORKER_LEASE_S                = "660"
    WORKER_VISIBILIDADE_INICIAL_S = "660"
    AGENDADOR_MODO                = "eventbridge"
    LEMBRETE_LAMBDA_ARN           = module.lembrete[0].arn
    SCHEDULER_ROLE_ARN            = module.scheduler[0].papel_arn
    DOCUMENTOS_MODO               = "lambda"
    LAMBDA_DOC_RENDER             = module.doc_render[0].nome
  }) : null
}

output "politica_worker_executores" {
  value = local.habilitar_executores ? jsonencode({
    Version = "2012-10-17"
    Statement = concat(jsondecode(module.scheduler[0].politica_worker).Statement, [{
      Effect = "Allow", Action = ["lambda:InvokeFunction"], Resource = concat([module.doc_render[0].arn], [for passo in module.passos : passo.arn])
    }])
  }) : null
}

output "lambda_doc_render_arn" {
  value = local.habilitar_executores ? module.doc_render[0].arn : null
}
