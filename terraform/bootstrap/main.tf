terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "conta_aws" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.conta_aws))
    error_message = "Informe o ID de 12 dígitos da conta AWS pessoal."
  }
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = [var.conta_aws]
  default_tags {
    tags = {
      projeto  = "prdal-careers"
      ambiente = "global"
      dono     = "gusta"
    }
  }
}

resource "aws_s3_bucket" "state" {
  bucket        = "prdal-careers-tfstate-${var.conta_aws}"
  force_destroy = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "seguranca" {
  bucket        = "prdal-careers-seguranca-${var.conta_aws}"
  force_destroy = false
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "seguranca" {
  bucket = aws_s3_bucket.seguranca.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "seguranca" {
  bucket = aws_s3_bucket.seguranca.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "seguranca" {
  bucket                  = aws_s3_bucket.seguranca.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket_state" {
  value = aws_s3_bucket.state.id
}

output "bucket_seguranca" {
  value = aws_s3_bucket.seguranca.id
}
