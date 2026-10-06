locals {
  github_repositorios_ids = {
    web                        = "1406302914"
    api                        = "1406303057"
    ai-service                 = "1406303215"
    doc-service                = "1406303337"
    worker                     = "1406303500"
    batch-migrar-arquivos-s3   = "1406303660"
    batch-reprocessar-keywords = "1406373239"
    lambda-enviar-lembrete     = "1406373404"
    contracts                  = "1406303824"
    infra                      = "1406304257"
  }
}

module "github_oidc" {
  count  = var.habilitar_base ? 1 : 0
  source = "../../modules/github-oidc"
  repositorios = merge({
    for imagem in local.imagens : imagem => {
      github          = "prdal-careers-${imagem}"
      github_id       = local.github_repositorios_ids[imagem]
      ecr_arn         = module.ecr[0].arns[imagem]
      publicar_imagem = true
    }
    }, {
    web       = { github = "prdal-careers-web", github_id = local.github_repositorios_ids.web, ecr_arn = null, publicar_imagem = false }
    contracts = { github = "prdal-careers-contracts", github_id = local.github_repositorios_ids.contracts, ecr_arn = null, publicar_imagem = false }
    infra     = { github = "prdal-careers-infra", github_id = local.github_repositorios_ids.infra, ecr_arn = null, publicar_imagem = false }
  })
}

output "github_oidc_papeis" {
  value = var.habilitar_base ? module.github_oidc[0].arns : null
}
