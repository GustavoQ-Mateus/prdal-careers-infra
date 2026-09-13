terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_ecs_cluster" "prdal" {
  name = "${var.project}-cluster"
}

resource "aws_db_instance" "postgres" {
  identifier          = "${var.project}-postgres"
  engine              = "postgres"
  engine_version      = "16"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  db_name             = "prdal_careers"
  username            = var.db_username
  password            = var.db_password
  skip_final_snapshot = true
}

resource "aws_docdb_cluster" "mongo" {
  cluster_identifier  = "${var.project}-docdb"
  master_username     = var.db_username
  master_password     = var.db_password
  skip_final_snapshot = true
}
