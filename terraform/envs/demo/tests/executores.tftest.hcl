mock_provider "aws" {
  override_during = plan
  mock_resource "aws_iam_role" { defaults = { arn = "arn:aws:iam::765656213653:role/teste" } }
  mock_resource "aws_cloudwatch_log_group" { defaults = { arn = "arn:aws:logs:us-east-1:765656213653:log-group:teste" } }
  mock_data "aws_region" { defaults = { region = "us-east-1" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "765656213653" } }
  mock_data "aws_availability_zones" { defaults = { names = ["us-east-1a", "us-east-1b"] } }
  mock_resource "aws_ecr_repository" { defaults = { arn = "arn:aws:ecr:us-east-1:765656213653:repository/teste" } }
  mock_resource "aws_sqs_queue" { defaults = { arn = "arn:aws:sqs:us-east-1:765656213653:teste" } }
  mock_resource "aws_iam_openid_connect_provider" { defaults = { arn = "arn:aws:iam::765656213653:oidc-provider/token.actions.githubusercontent.com" } }
  mock_resource "aws_lambda_function" { defaults = { arn = "arn:aws:lambda:us-east-1:765656213653:function:teste" } }
  mock_resource "aws_batch_compute_environment" { defaults = { arn = "arn:aws:batch:us-east-1:765656213653:compute-environment/teste" } }
  mock_resource "aws_ecs_cluster" { defaults = { arn = "arn:aws:ecs:us-east-1:765656213653:cluster/teste" } }
  mock_resource "aws_service_discovery_http_namespace" { defaults = { arn = "arn:aws:servicediscovery:us-east-1:765656213653:namespace/ns-teste" } }
  mock_resource "aws_lb_target_group" { defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:765656213653:targetgroup/teste/0123456789abcdef" } }
  mock_resource "aws_cloudfront_distribution" { defaults = { arn = "arn:aws:cloudfront::765656213653:distribution/TESTE" } }
  mock_resource "aws_s3_bucket" { defaults = { arn = "arn:aws:s3:::teste", bucket_regional_domain_name = "teste.s3.us-east-1.amazonaws.com" } }
  mock_data "aws_secretsmanager_secret_version" { defaults = { secret_string = "token-de-servico-de-teste-com-mais-de-32-bytes" } }
}
mock_provider "random" { override_during = plan }

run "lambda_sem_banco_sem_chave" {
  command = plan
  module { source = "../../modules/lambda" }
  variables {
    nome               = "teste-keywords"
    imagem             = "765656213653.dkr.ecr.us-east-1.amazonaws.com/prdal-demo/ai-service:teste"
    comando            = ["app.lambda_handler.handler"]
    segredos_arns      = { ANTHROPIC_API_KEY = "arn:aws:secretsmanager:us-east-1:765656213653:secret:teste" }
    topico_alertas_arn = "arn:aws:sns:us-east-1:765656213653:teste"
  }
  assert {
    condition     = length(aws_lambda_function.funcao.vpc_config) == 0 && aws_lambda_function.funcao.reserved_concurrent_executions == -1
    error_message = "Lambda deve ficar fora da VPC e usar a cota compartilhada do demo."
  }
  assert {
    condition     = toset(keys(aws_lambda_function.funcao.environment[0].variables)) == toset(["ANTHROPIC_API_KEY_ARN"]) && toset(jsondecode(aws_iam_role_policy.funcao.policy).Statement[1].Resource) == toset(values(var.segredos_arns))
    error_message = "Somente ARN pode entrar no ambiente e somente o segredo proprio pode ser lido."
  }
  assert {
    condition     = toset(keys(aws_cloudwatch_metric_alarm.funcao)) == toset(["Errors", "Throttles"])
    error_message = "Erro e throttling precisam de alarme."
  }
}

run "scheduler_restrito" {
  command = plan
  module { source = "../../modules/scheduler" }
  variables {
    nome       = "teste"
    lambda_arn = "arn:aws:lambda:us-east-1:765656213653:function:lembrete"
  }
  assert {
    condition     = jsondecode(aws_iam_role.agendador.assume_role_policy).Statement[0].Condition.ArnEquals["aws:SourceArn"] == "arn:aws:scheduler:us-east-1:765656213653:schedule-group/default"
    error_message = "Confianca do Scheduler deve restringir conta e grupo usados pelo worker."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.invocar.policy).Statement[0].Resource == var.lambda_arn && endswith(jsondecode(output.politica_worker).Statement[0].Resource, ":schedule/default/acao-*")
    error_message = "Scheduler so invoca lembrete e worker so gerencia seus agendamentos."
  }
}

run "batch_isolado" {
  command = plan
  module { source = "../../modules/batch" }
  variables {
    nome                    = "teste"
    vpc_id                  = "vpc-0123456789abcdef0"
    subnets                 = ["subnet-0123456789abcdef0", "subnet-1123456789abcdef0"]
    banco_security_group_id = "sg-0123456789abcdef0"
    jobs = {
      batch-migrar-arquivos-s3 = {
        imagem           = "teste-migracao"
        ambiente         = { ARQUIVOS_LOCAIS_DIR = "/app/storage" }
        segredos_arns    = { DATABASE_URL = "arn:aws:secretsmanager:us-east-1:765656213653:secret:database" }
        politica_tarefa  = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["s3:PutObject"], Resource = "arn:aws:s3:::teste/*" }] })
        efs_id           = "fs-0123456789abcdef0"
        efs_access_point = "fsap-0123456789abcdef0"
      }
      batch-reprocessar-keywords = {
        imagem        = "teste-keywords"
        ambiente      = { LOTES_MODO = "anthropic" }
        segredos_arns = { ANTHROPIC_API_KEY = "arn:aws:secretsmanager:us-east-1:765656213653:secret:chave" }
      }
    }
  }
  assert {
    condition     = aws_batch_compute_environment.tarefas.compute_resources[0].type == "FARGATE" && aws_batch_compute_environment.tarefas.compute_resources[0].max_vcpus == 2 && length(aws_security_group.tarefas.ingress) == 0
    error_message = "Batch deve ter limite de CPU e nenhuma entrada publica."
  }
  assert {
    condition     = length(aws_batch_job_definition.jobs) == 2 && length(aws_iam_role_policy.tarefa) == 1 && length(aws_iam_role_policy.segredos) == 2
    error_message = "Cada job deve ter imagem e papel proprios, sem permissoes desnecessarias."
  }
  assert {
    condition     = jsondecode(aws_batch_job_definition.jobs["batch-migrar-arquivos-s3"].container_properties).mountPoints[0].readOnly && jsondecode(aws_batch_job_definition.jobs["batch-reprocessar-keywords"].container_properties).networkConfiguration.assignPublicIp == "ENABLED"
    error_message = "Migracao deve ler EFS e demo deve sair sem NAT."
  }
}

run "contrato_completo" {
  command = plan
  variables {
    email_orcamento = "orcamento@example.invalid"
    habilitar_base  = true
    imagens_servicos = {
      ai-service             = "765656213653.dkr.ecr.us-east-1.amazonaws.com/prdal-demo/ai-service@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      lambda-enviar-lembrete = "765656213653.dkr.ecr.us-east-1.amazonaws.com/prdal-demo/lambda-enviar-lembrete@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
      api                    = "765656213653.dkr.ecr.us-east-1.amazonaws.com/prdal-demo/api@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
      worker                 = "765656213653.dkr.ecr.us-east-1.amazonaws.com/prdal-demo/worker@sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
      doc-service            = "765656213653.dkr.ecr.us-east-1.amazonaws.com/prdal-demo/doc-service@sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
    }
  }
  assert {
    condition     = length(module.passos) == 5 && length(module.lembrete) == 1 && length(module.doc_render) == 1 && length(module.api) == 1 && length(module.worker) == 1 && length(module.ai_service) == 1 && length(module.alb) == 1 && length(module.cdn) == 1 && output.ambiente_worker_executores.EXECUTOR_MODO == "lambda"
    error_message = "O demo deve ligar as Lambdas, os tres servicos ECS, ALB e CDN."
  }
  assert {
    condition     = tonumber(output.ambiente_worker_executores.WORKER_LEASE_S) * 1000 > tonumber(output.ambiente_worker_executores.AI_STEP_TIMEOUT_MS) && tonumber(output.ambiente_worker_executores.WORKER_VISIBILIDADE_INICIAL_S) * 1000 > tonumber(output.ambiente_worker_executores.AI_STEP_TIMEOUT_MS)
    error_message = "O lease e a visibilidade do worker devem durar mais que a espera por uma etapa de IA."
  }
}

run "impedir_imagens_incompletas" {
  command = plan
  variables {
    email_orcamento = "orcamento@example.invalid"
    habilitar_base  = true
    imagens_servicos = {
      ai-service                 = "765656213653.dkr.ecr.us-east-1.amazonaws.com/prdal-demo/ai-service@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      lambda-enviar-lembrete     = "765656213653.dkr.ecr.us-east-1.amazonaws.com/prdal-demo/lambda-enviar-lembrete@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
      batch-migrar-arquivos-s3   = "765656213653.dkr.ecr.us-east-1.amazonaws.com/prdal-demo/batch-migrar-arquivos-s3@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
      batch-reprocessar-keywords = "765656213653.dkr.ecr.us-east-1.amazonaws.com/prdal-demo/batch-reprocessar-keywords@sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
    }
  }
  expect_failures = [var.imagens_servicos]
}
