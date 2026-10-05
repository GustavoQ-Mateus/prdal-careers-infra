variable "nome" { type = string }
variable "vpc_id" { type = string }
variable "subnets" { type = list(string) }
variable "banco_security_group_id" { type = string }
variable "jobs" {
  type = map(object({
    imagem           = string
    ambiente         = map(string)
    segredos_arns    = map(string)
    politica_tarefa  = optional(string)
    efs_id           = optional(string)
    efs_access_point = optional(string)
    cpu              = optional(string, "0.5")
    memoria          = optional(string, "1024")
    timeout          = optional(number, 86400)
  }))
}

data "aws_region" "atual" {}

resource "aws_security_group" "tarefas" {
  name_prefix = "${var.nome}-batch-"
  description = "Saida das tarefas Batch sem entrada publica"
  vpc_id      = var.vpc_id
  ingress     = []
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_security_group_ingress_rule" "banco" {
  security_group_id            = var.banco_security_group_id
  referenced_security_group_id = aws_security_group.tarefas.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_batch_compute_environment" "tarefas" {
  name = "${var.nome}-batch"
  type = "MANAGED"
  compute_resources {
    type               = "FARGATE"
    max_vcpus          = 2
    subnets            = var.subnets
    security_group_ids = [aws_security_group.tarefas.id]
  }
}

resource "aws_batch_job_queue" "tarefas" {
  name     = "${var.nome}-batch"
  state    = "ENABLED"
  priority = 1
  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.tarefas.arn
  }
}

resource "aws_cloudwatch_log_group" "jobs" {
  for_each          = var.jobs
  name              = "/aws/batch/${var.nome}-${each.key}"
  retention_in_days = 7
}

resource "aws_iam_role" "execucao" {
  for_each = var.jobs
  name     = "${var.nome}-${each.key}-execucao"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "execucao" {
  for_each   = var.jobs
  role       = aws_iam_role.execucao[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "segredos" {
  for_each = { for nome, job in var.jobs : nome => job if length(job.segredos_arns) > 0 }
  name     = "ler-segredos"
  role     = aws_iam_role.execucao[each.key].id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = values(each.value.segredos_arns) }]
  })
}

resource "aws_iam_role" "tarefa" {
  for_each           = var.jobs
  name               = "${var.nome}-${each.key}-tarefa"
  assume_role_policy = aws_iam_role.execucao[each.key].assume_role_policy
}

resource "aws_iam_role_policy" "tarefa" {
  for_each = { for nome, job in var.jobs : nome => job if job.politica_tarefa != null }
  name     = "executar-job"
  role     = aws_iam_role.tarefa[each.key].id
  policy   = each.value.politica_tarefa
}

resource "aws_batch_job_definition" "jobs" {
  for_each              = var.jobs
  name                  = "${var.nome}-${each.key}"
  type                  = "container"
  platform_capabilities = ["FARGATE"]
  retry_strategy { attempts = 1 }
  timeout { attempt_duration_seconds = each.value.timeout }
  container_properties = jsonencode({
    image            = each.value.imagem
    executionRoleArn = aws_iam_role.execucao[each.key].arn
    jobRoleArn       = aws_iam_role.tarefa[each.key].arn
    resourceRequirements = [
      { type = "VCPU", value = each.value.cpu },
      { type = "MEMORY", value = each.value.memoria }
    ]
    environment                  = [for nome, valor in each.value.ambiente : { name = nome, value = valor }]
    secrets                      = [for nome, arn in each.value.segredos_arns : { name = nome, valueFrom = arn }]
    networkConfiguration         = { assignPublicIp = "ENABLED" }
    fargatePlatformConfiguration = { platformVersion = "1.4.0" }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.jobs[each.key].name
        awslogs-region        = data.aws_region.atual.region
        awslogs-stream-prefix = "job"
      }
    }
    volumes = each.value.efs_id == null ? [] : [{
      name = "arquivos"
      efsVolumeConfiguration = {
        fileSystemId        = each.value.efs_id
        transitEncryption   = "ENABLED"
        authorizationConfig = { accessPointId = each.value.efs_access_point, iam = "ENABLED" }
      }
    }]
    mountPoints = each.value.efs_id == null ? [] : [{ sourceVolume = "arquivos", containerPath = "/app/storage", readOnly = true }]
  })
  depends_on = [aws_iam_role_policy_attachment.execucao, aws_iam_role_policy.segredos, aws_iam_role_policy.tarefa]
}

output "fila_arn" { value = aws_batch_job_queue.tarefas.arn }
output "jobs_arns" { value = { for nome, job in aws_batch_job_definition.jobs : nome => job.arn } }
output "security_group_id" { value = aws_security_group.tarefas.id }
