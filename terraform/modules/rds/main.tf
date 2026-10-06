variable "nome" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnets_privadas" {
  type = list(string)
}

variable "snapshot_identifier" {
  type    = string
  default = null
}

resource "random_password" "postgres" {
  length  = 40
  special = false
}

resource "aws_security_group" "banco" {
  name_prefix = "${var.nome}-banco-"
  description = "Acesso privado ao PostgreSQL"
  vpc_id      = var.vpc_id
  tags = {
    Name = "${var.nome}-banco"
  }
}

resource "aws_db_subnet_group" "banco" {
  name       = "${var.nome}-banco"
  subnet_ids = var.subnets_privadas
}

resource "aws_db_instance" "postgres" {
  identifier                   = "${var.nome}-postgres"
  engine                       = "postgres"
  engine_version               = "16"
  instance_class               = "db.t4g.micro"
  allocated_storage            = 20
  storage_type                 = "gp3"
  storage_encrypted            = true
  password                     = random_password.postgres.result
  multi_az                     = false
  db_subnet_group_name         = aws_db_subnet_group.banco.name
  vpc_security_group_ids       = [aws_security_group.banco.id]
  publicly_accessible          = false
  backup_retention_period      = 7
  deletion_protection          = false
  skip_final_snapshot          = true
  delete_automated_backups     = true
  apply_immediately            = true
  snapshot_identifier          = var.snapshot_identifier
  db_name                      = var.snapshot_identifier == null ? "prdal_careers" : null
  username                     = var.snapshot_identifier == null ? "prdal" : null
  auto_minor_version_upgrade   = true
  performance_insights_enabled = false
  lifecycle {
    ignore_changes = [snapshot_identifier]
  }
}

output "identifier" {
  value = aws_db_instance.postgres.identifier
}

output "endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "password" {
  value     = random_password.postgres.result
  sensitive = true
}

output "security_group_id" {
  value = aws_security_group.banco.id
}

output "segredo_mestre_arn" {
  value = try(aws_db_instance.postgres.master_user_secret[0].secret_arn, null)
}
