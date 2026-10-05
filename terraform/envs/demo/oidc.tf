module "github_oidc" {
  count  = var.habilitar_base ? 1 : 0
  source = "../../modules/github-oidc"
  repositorios = merge({
    for imagem in local.imagens : imagem => {
      github          = "prdal-careers-${imagem}"
      ecr_arn         = module.ecr[0].arns[imagem]
      publicar_imagem = true
    }
    }, {
    web       = { github = "prdal-careers-web", ecr_arn = null, publicar_imagem = false }
    contracts = { github = "prdal-careers-contracts", ecr_arn = null, publicar_imagem = false }
    infra     = { github = "prdal-careers-infra", ecr_arn = null, publicar_imagem = false }
  })
}

output "github_oidc_papeis" {
  value = var.habilitar_base ? module.github_oidc[0].arns : null
}
