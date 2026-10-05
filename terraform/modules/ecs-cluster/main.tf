variable "nome" {
  type = string
}

resource "aws_ecs_cluster" "principal" {
  name = var.nome
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "principal" {
  cluster_name       = aws_ecs_cluster.principal.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

output "arn" {
  value = aws_ecs_cluster.principal.arn
}
