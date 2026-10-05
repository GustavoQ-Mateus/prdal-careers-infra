module "segredos" {
  count  = var.habilitar_base ? 1 : 0
  source = "../../modules/segredos"
  nome   = "prdal-demo"
}

output "segredos_arns" {
  value = var.habilitar_base ? module.segredos[0].arns : null
}
