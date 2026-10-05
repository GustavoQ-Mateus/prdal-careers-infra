variable "nome" {
  type = string
}

variable "imagens" {
  type = set(string)
}

resource "aws_ecr_repository" "imagem" {
  for_each             = var.imagens
  name                 = "${var.nome}/${each.key}"
  force_delete         = true
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "imagem" {
  for_each   = aws_ecr_repository.imagem
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Reter vinte imagens"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = {
        type = "expire"
      }
    }]
  })
}

output "arns" {
  value = { for nome, repo in aws_ecr_repository.imagem : nome => repo.arn }
}

output "urls" {
  value = { for nome, repo in aws_ecr_repository.imagem : nome => repo.repository_url }
}
