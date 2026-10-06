mock_provider "aws" {
  override_during = plan
  mock_data "aws_availability_zones" {
    defaults = { names = ["us-east-1a", "us-east-1b"] }
  }
  mock_resource "aws_ecr_repository" {
    defaults = { arn = "arn:aws:ecr:us-east-1:765656213653:repository/teste" }
  }
  mock_resource "aws_sqs_queue" {
    defaults = { arn = "arn:aws:sqs:us-east-1:765656213653:teste" }
  }
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = { arn = "arn:aws:iam::765656213653:oidc-provider/token.actions.githubusercontent.com" }
  }
}

mock_provider "random" { override_during = plan }

run "somente_orcamento" {
  command = plan
  variables {
    email_orcamento = "orcamento@example.invalid"
    habilitar_base  = false
  }
  assert {
    condition     = length(module.network) == 0 && length(module.ecr) == 0 && length(module.rds) == 0
    error_message = "A etapa do orçamento não pode criar a base."
  }
}

run "base_com_batch" {
  command = plan
  variables {
    email_orcamento = "orcamento@example.invalid"
    habilitar_base  = true
  }
  assert {
    condition     = toset(keys(output.ecr_urls)) == toset(["api", "worker", "ai-service", "doc-service", "batch-migrar-arquivos-s3", "batch-reprocessar-keywords", "lambda-enviar-lembrete"])
    error_message = "A imagem do Batch precisa seguir o nome do repositório."
  }
  assert {
    condition     = length(output.github_oidc_papeis) == 10
    error_message = "Cada espelho precisa ter seu papel OIDC."
  }
}

run "orcamento_bruto" {
  command = plan
  module { source = "../../modules/orcamento" }
  variables {
    email         = "orcamento@example.invalid"
    limite_mensal = 100
  }
  assert {
    condition     = aws_budgets_budget.mensal.cost_types[0].include_credit == false && length(aws_budgets_budget.mensal.notification) == 5
    error_message = "O orçamento precisa excluir créditos e manter cinco notificações."
  }
}

run "rede_sem_nat" {
  command = plan
  module { source = "../../modules/network" }
  variables {
    nome           = "teste"
    nat_habilitado = false
  }
  assert {
    condition     = length(aws_subnet.publica) == 2 && length(aws_subnet.privada) == 2 && length(aws_nat_gateway.principal) == 0
    error_message = "O demo deve ter duas zonas e nenhum NAT."
  }
}

run "banco_privado" {
  command = plan
  module { source = "../../modules/rds" }
  variables {
    nome             = "teste"
    vpc_id           = "vpc-0123456789abcdef0"
    subnets_privadas = ["subnet-0123456789abcdef0", "subnet-1123456789abcdef0"]
  }
  assert {
    condition     = aws_db_instance.postgres.publicly_accessible == false && aws_db_instance.postgres.storage_encrypted && aws_db_instance.postgres.manage_master_user_password
    error_message = "O banco deve ser privado, criptografado e ter senha gerenciada."
  }
}

run "fila_com_dlq" {
  command = plan
  module { source = "../../modules/sqs" }
  variables { nome = "teste" }
  assert {
    condition     = jsondecode(aws_sqs_queue.jobs.redrive_policy).maxReceiveCount == 3
    error_message = "A fila precisa enviar à DLQ após três tentativas."
  }
}

run "oidc_batch_restrito" {
  command = plan
  module { source = "../../modules/github-oidc" }
  variables {
    repositorios = {
      batch-migrar-arquivos-s3 = {
        github          = "prdal-careers-batch-migrar-arquivos-s3"
        github_id       = "1406303660"
        ecr_arn         = "arn:aws:ecr:us-east-1:765656213653:repository/prdal-demo/batch-migrar-arquivos-s3"
        publicar_imagem = true
      }
      web = {
        github          = "prdal-careers-web"
        github_id       = "1406302914"
        ecr_arn         = null
        publicar_imagem = false
      }
    }
  }
  assert {
    condition     = jsondecode(aws_iam_role.publicar["batch-migrar-arquivos-s3"].assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:GustavoQ-Mateus@199433320/prdal-careers-batch-migrar-arquivos-s3@1406303660:ref:refs/heads/main"
    error_message = "O papel Batch deve confiar somente na main e nos IDs imutaveis do espelho correspondente."
  }
  assert {
    condition     = jsondecode(aws_iam_role.publicar["web"].assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:GustavoQ-Mateus@199433320/prdal-careers-web@1406302914:ref:refs/heads/main" && alltrue([for papel in aws_iam_role.publicar : jsondecode(papel.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com"])
    error_message = "Cada papel precisa restringir o proprio espelho e a audiencia do STS."
  }
  assert {
    condition     = length(aws_iam_role_policy.publicar) == 1 && jsondecode(aws_iam_role_policy.publicar["batch-migrar-arquivos-s3"].policy).Statement[1].Resource == var.repositorios["batch-migrar-arquivos-s3"].ecr_arn
    error_message = "A publicação deve alcançar somente o ECR próprio; web ainda não recebe acesso."
  }
}

run "oidc_sem_id_rejeitado" {
  command = plan
  module { source = "../../modules/github-oidc" }
  variables {
    repositorios = {
      web = {
        github          = "prdal-careers-web"
        github_id       = ""
        ecr_arn         = null
        publicar_imagem = false
      }
    }
  }
  expect_failures = [var.repositorios]
}
