locals {
  habilitar_servicos = var.habilitar_base && length(var.imagens_servicos) > 0
  imagem_api         = local.habilitar_servicos ? var.imagens_servicos["api"] : null
}

resource "random_password" "origem_cloudfront" {
  count   = local.habilitar_servicos ? 1 : 0
  length  = 48
  special = false
}

resource "aws_service_discovery_http_namespace" "servicos" {
  count = local.habilitar_servicos ? 1 : 0
  name  = "prdal-demo"
}

resource "aws_security_group" "servicos" {
  count       = local.habilitar_servicos ? 1 : 0
  name_prefix = "prdal-demo-servicos-"
  description = "Tarefas ECS do demo"
  vpc_id      = module.network[0].vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_security_group_ingress_rule" "servicos_internos" {
  count                        = local.habilitar_servicos ? 1 : 0
  security_group_id            = aws_security_group.servicos[0].id
  referenced_security_group_id = aws_security_group.servicos[0].id
  ip_protocol                  = "-1"
}

module "alb" {
  count                     = local.habilitar_servicos ? 1 : 0
  source                    = "../../modules/alb"
  nome                      = "prdal-demo"
  vpc_id                    = module.network[0].vpc_id
  subnets_publicas          = module.network[0].subnets_publicas
  cloudfront_prefix_list_id = "pl-3b927c52"
  origin_header_value       = random_password.origem_cloudfront[0].result
  origin_header_habilitado  = true
}

module "cdn" {
  count                        = local.habilitar_servicos ? 1 : 0
  source                       = "../../modules/cdn"
  nome                         = "prdal-demo"
  bucket_web                   = "prdal-careers-demo-web-765656213653"
  dominio_alb                  = module.alb[0].dns
  alb_origin_protocol_policy   = "http-only"
  alb_origin_header_value      = random_password.origem_cloudfront[0].result
  alb_origin_header_habilitado = true
}

resource "aws_vpc_security_group_ingress_rule" "servicos_alb" {
  count                        = local.habilitar_servicos ? 1 : 0
  security_group_id            = aws_security_group.servicos[0].id
  referenced_security_group_id = module.alb[0].security_group_id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "servicos_banco" {
  count                        = local.habilitar_servicos ? 1 : 0
  security_group_id            = module.rds[0].security_group_id
  referenced_security_group_id = aws_security_group.servicos[0].id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

locals {
  politica_s3 = local.habilitar_servicos ? [
    {
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
      Resource = "arn:aws:s3:::${module.artefatos[0].bucket}/*"
    },
    {
      Effect   = "Allow"
      Action   = ["s3:ListBucket"]
      Resource = "arn:aws:s3:::${module.artefatos[0].bucket}"
    }
  ] : []
  politica_api = local.habilitar_servicos ? jsonencode({
    Version = "2012-10-17"
    Statement = concat(local.politica_s3, [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = module.jobs[0].arn
      }, {
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = module.doc_render[0].arn
    }])
  }) : null
  politica_worker = local.habilitar_servicos ? jsonencode({
    Version = "2012-10-17"
    Statement = concat(local.politica_s3, [{
      Effect   = "Allow"
      Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility", "sqs:GetQueueAttributes", "sqs:SendMessage"]
      Resource = module.jobs[0].arn
      }], jsondecode(module.scheduler[0].politica_worker).Statement, [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = concat([module.doc_render[0].arn], [for passo in module.passos : passo.arn])
    }])
  }) : null
  ambiente_worker_executores = local.habilitar_servicos ? merge({
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
  }) : {}
  ambiente_api = local.habilitar_servicos ? {
    AI_SERVICE_URL         = "http://ai-service:8000"
    AI_LLM_TIMEOUT_MS      = "60000"
    AI_GENERATE_TIMEOUT_MS = "300000"
    API_PREFIXO            = "/api"
    API_SELF_URL           = "http://api:3000"
    CORS_ORIGINS           = "https://${module.cdn[0].dominio}"
    PRDAL_HTTPS            = "true"
    PRDAL_AMBIENTE         = "producao"
    TRUST_PROXY            = "1"
    API_VERSAO             = "v1"
    S3_BUCKET              = module.artefatos[0].bucket
    SQS_FILA_JOBS_URL      = module.jobs[0].url
    AWS_REGION             = "us-east-1"
    DOCUMENTOS_MODO        = "lambda"
    LAMBDA_DOC_RENDER      = module.doc_render[0].nome
  } : {}
  ambiente_worker = local.habilitar_servicos ? merge(local.ambiente_worker_executores, {
    AI_SERVICE_URL      = "http://ai-service:8000"
    AWS_REGION          = "us-east-1"
    SQS_FILA_JOBS_URL   = module.jobs[0].url
    S3_BUCKET           = module.artefatos[0].bucket
    DOCUMENTOS_MODO     = "lambda"
    LAMBDA_DOC_RENDER   = module.doc_render[0].nome
    WORKER_CONCORRENCIA = "2"
  }) : {}
}

module "api" {
  count                         = local.habilitar_servicos ? 1 : 0
  source                        = "../../modules/ecs-service"
  nome                          = "prdal-demo-api"
  cluster_arn                   = module.cluster[0].arn
  imagem                        = var.imagens_servicos["api"]
  subnets                       = module.network[0].subnets_publicas
  security_group_ids            = [aws_security_group.servicos[0].id]
  porta                         = 3000
  cpu                           = 512
  memoria                       = 1024
  ip_publico                    = true
  target_group_arn              = module.alb[0].target_group_arn
  service_connect_namespace_arn = aws_service_discovery_http_namespace.servicos[0].arn
  service_connect_nome          = "api"
  ambiente                      = local.ambiente_api
  segredos_arns = {
    DATABASE_URL  = aws_secretsmanager_secret.database_url[0].arn
    JWT_SECRET    = module.segredos[0].arns.JWT_SECRET
    SERVICE_TOKEN = module.segredos[0].arns.SERVICE_TOKEN
  }
  politica_tarefa = local.politica_api
  depends_on      = [module.segredos, aws_secretsmanager_secret_version.database_url]
}

module "worker" {
  count                         = local.habilitar_servicos ? 1 : 0
  source                        = "../../modules/ecs-service"
  nome                          = "prdal-demo-worker"
  cluster_arn                   = module.cluster[0].arn
  imagem                        = var.imagens_servicos["worker"]
  subnets                       = module.network[0].subnets_publicas
  security_group_ids            = [aws_security_group.servicos[0].id]
  porta                         = 3001
  cpu                           = 512
  memoria                       = 1024
  spot                          = true
  ip_publico                    = true
  service_connect_namespace_arn = aws_service_discovery_http_namespace.servicos[0].arn
  service_connect_nome          = "worker"
  ambiente                      = local.ambiente_worker
  segredos_arns = {
    DATABASE_URL  = aws_secretsmanager_secret.database_url[0].arn
    SERVICE_TOKEN = module.segredos[0].arns.SERVICE_TOKEN
  }
  politica_tarefa = local.politica_worker
  depends_on      = [module.segredos, aws_secretsmanager_secret_version.database_url]
}

module "ai_service" {
  count                         = local.habilitar_servicos ? 1 : 0
  source                        = "../../modules/ecs-service"
  nome                          = "prdal-demo-ai-service"
  cluster_arn                   = module.cluster[0].arn
  imagem                        = var.imagens_servicos["ai-service"]
  subnets                       = module.network[0].subnets_publicas
  security_group_ids            = [aws_security_group.servicos[0].id]
  porta                         = 8000
  cpu                           = 512
  memoria                       = 2048
  ip_publico                    = true
  service_connect_namespace_arn = aws_service_discovery_http_namespace.servicos[0].arn
  service_connect_nome          = "ai-service"
  ambiente = {
    AI_MODEL           = var.ai_model
    ANTHROPIC_BASE_URL = "https://openrouter.ai/api"
    AI_MAX_TOKENS      = "16000"
    AI_MAX_RETRIES     = "2"
    AI_JUIZ_RELACAO    = "1"
    AI_TIMEOUT_PISO_S  = "5"
    AI_TIMEOUT_TETO_S  = "120"
    PRDAL_AMBIENTE     = "producao"
    EMBED_MODEL        = "intfloat/multilingual-e5-small"
    EMBED_DIMENSAO     = "384"
  }
  segredos_arns = {
    ANTHROPIC_API_KEY = module.segredos[0].arns.ANTHROPIC_API_KEY
    SERVICE_TOKEN     = module.segredos[0].arns.SERVICE_TOKEN
  }
  depends_on = [module.segredos]
}

module "migracao" {
  count              = local.habilitar_servicos ? 1 : 0
  source             = "../../modules/ecs-service"
  nome               = "prdal-demo-migracao"
  cluster_arn        = module.cluster[0].arn
  imagem             = local.imagem_api
  subnets            = module.network[0].subnets_publicas
  security_group_ids = [aws_security_group.servicos[0].id]
  porta              = 3000
  cpu                = 512
  memoria            = 1024
  ip_publico         = true
  servico_habilitado = false
  comando            = ["npx", "prisma", "migrate", "deploy"]
  segredos_arns      = { DATABASE_URL = aws_secretsmanager_secret.database_url[0].arn }
  depends_on         = [aws_secretsmanager_secret_version.database_url]
}

output "url_demo" {
  value = local.habilitar_servicos ? "https://${module.cdn[0].dominio}" : null
}

output "bucket_web" {
  value = local.habilitar_servicos ? module.cdn[0].bucket : null
}

output "ecs_migracao_task_definition" {
  value = local.habilitar_servicos ? module.migracao[0].task_definition_arn : null
}
