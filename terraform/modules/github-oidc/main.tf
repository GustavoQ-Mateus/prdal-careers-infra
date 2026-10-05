variable "repositorios" {
  type = map(object({
    github          = string
    ecr_arn         = string
    publicar_imagem = bool
  }))
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "publicar" {
  for_each = var.repositorios
  name     = "prdal-demo-publicar-${each.key}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:GustavoQ-Mateus/${each.value.github}:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "publicar" {
  for_each = { for nome, repo in var.repositorios : nome => repo if repo.publicar_imagem }
  name     = "publicar-ecr"
  role     = aws_iam_role.publicar[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ecr:GetAuthorizationToken"]
      Resource = "*"
      }, {
      Effect = "Allow"
      Action = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ]
      Resource = each.value.ecr_arn
    }]
  })
}

output "arns" {
  value = { for nome, papel in aws_iam_role.publicar : nome => papel.arn }
}
