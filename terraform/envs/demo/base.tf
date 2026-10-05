module "network" {
  count          = var.habilitar_base ? 1 : 0
  source         = "../../modules/network"
  nome           = "prdal-demo"
  nat_habilitado = false
}
