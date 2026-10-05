module "network" {
  count          = var.habilitar_base ? 1 : 0
  source         = "../../modules/network"
  nome           = "prdal-demo"
  nat_habilitado = false
}

locals {
  imagens = toset(["api", "worker", "ai-service", "doc-service", "batch-migrar-arquivos-s3"])
}

module "ecr" {
  count   = var.habilitar_base ? 1 : 0
  source  = "../../modules/ecr"
  nome    = "prdal-demo"
  imagens = local.imagens
}

module "cluster" {
  count  = var.habilitar_base ? 1 : 0
  source = "../../modules/ecs-cluster"
  nome   = "prdal-demo"
}

output "ecr_urls" {
  value = var.habilitar_base ? module.ecr[0].urls : null
}
