variable "nome" { type = string }
variable "cluster_arn" { type = string }
variable "imagem" { type = string }
variable "subnets" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "porta" { type = number }
variable "cpu" { type = number }
variable "memoria" { type = number }
variable "ambiente" {
  type    = map(string)
  default = {}
}
variable "politica_tarefa" {
  type    = string
  default = null
}
variable "spot" {
  type    = bool
  default = false
}
variable "min_tarefas" {
  type    = number
  default = 1
}
variable "max_tarefas" {
  type    = number
  default = 1
}
variable "target_group_arn" {
  type    = string
  default = null
}
variable "ip_publico" {
  type    = bool
  default = true
}
variable "segredos_arns" {
  type    = map(string)
  default = {}
}

data "aws_region" "atual" {}

resource "aws_cloudwatch_log_group" "servico" {
  name              = "/ecs/${var.nome}"
  retention_in_days = 7
}

resource "aws_iam_role" "execucao" {
  name = "${var.nome}-execucao"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execucao" {
  role       = aws_iam_role.execucao.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "segredos" {
  count = length(var.segredos_arns) > 0 ? 1 : 0
  name  = "ler-segredos"
  role  = aws_iam_role.execucao.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = values(var.segredos_arns)
    }]
  })
}

resource "aws_iam_role" "tarefa" {
  name = "${var.nome}-tarefa"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_ecs_task_definition" "servico" {
  family                   = var.nome
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memoria
  execution_role_arn       = aws_iam_role.execucao.arn
  task_role_arn            = aws_iam_role.tarefa.arn
  container_definitions = jsonencode([{
    name        = var.nome
    image       = var.imagem
    essential   = true
    environment = [for nome, valor in var.ambiente : { name = nome, value = valor }]
    portMappings = [{
      containerPort = var.porta
      protocol      = "tcp"
    }]
    secrets = [for nome, arn in var.segredos_arns : {
      name      = nome
      valueFrom = arn
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.servico.name
        awslogs-region        = data.aws_region.atual.region
        awslogs-stream-prefix = var.nome
      }
    }
  }])
  depends_on = [aws_iam_role_policy_attachment.execucao, aws_iam_role_policy.segredos]
}

resource "aws_iam_role_policy" "tarefa" {
  count  = var.politica_tarefa == null ? 0 : 1
  name   = "acesso-aplicacao"
  role   = aws_iam_role.tarefa.id
  policy = var.politica_tarefa
}

resource "aws_ecs_service" "servico" {
  name            = var.nome
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.servico.arn
  desired_count   = var.min_tarefas
  capacity_provider_strategy {
    capacity_provider = var.spot ? "FARGATE_SPOT" : "FARGATE"
    weight            = 1
  }
  network_configuration {
    subnets          = var.subnets
    security_groups  = var.security_group_ids
    assign_public_ip = var.ip_publico
  }
  dynamic "load_balancer" {
    for_each = var.target_group_arn == null ? [] : [var.target_group_arn]
    content {
      target_group_arn = load_balancer.value
      container_name   = var.nome
      container_port   = var.porta
    }
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}

resource "aws_appautoscaling_target" "servico" {
  count              = var.max_tarefas > var.min_tarefas ? 1 : 0
  min_capacity       = var.min_tarefas
  max_capacity       = var.max_tarefas
  resource_id        = "service/${element(split("/", var.cluster_arn), 1)}/${aws_ecs_service.servico.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  count              = var.max_tarefas > var.min_tarefas ? 1 : 0
  name               = "${var.nome}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.servico[0].resource_id
  scalable_dimension = aws_appautoscaling_target.servico[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.servico[0].service_namespace
  target_tracking_scaling_policy_configuration {
    target_value = 70
    predefined_metric_specification { predefined_metric_type = "ECSServiceAverageCPUUtilization" }
  }
}
