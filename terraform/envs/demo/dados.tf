variable "snapshot_identifier" {
  type    = string
  default = null
}

module "rds" {
  count               = var.habilitar_base ? 1 : 0
  source              = "../../modules/rds"
  nome                = "prdal-demo"
  vpc_id              = module.network[0].vpc_id
  subnets_privadas    = module.network[0].subnets_privadas
  snapshot_identifier = var.snapshot_identifier
}

module "artefatos" {
  count  = var.habilitar_base ? 1 : 0
  source = "../../modules/s3-artefatos"
  nome   = "prdal-careers-demo-artefatos-765656213653"
}

module "jobs" {
  count  = var.habilitar_base ? 1 : 0
  source = "../../modules/sqs"
  nome   = "prdal-demo"
}

output "SQS_FILA_JOBS_URL" {
  value = var.habilitar_base ? module.jobs[0].url : null
}

output "S3_BUCKET" {
  value = var.habilitar_base ? module.artefatos[0].bucket : null
}

output "RDS_IDENTIFIER" {
  value = var.habilitar_base ? module.rds[0].identifier : null
}
