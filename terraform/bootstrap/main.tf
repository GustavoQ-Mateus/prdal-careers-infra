terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["765656213653"]
  default_tags {
    tags = {
      projeto  = "prdal-careers"
      ambiente = "global"
      dono     = "gusta"
    }
  }
}

resource "aws_s3_bucket" "state" {
  bucket        = "prdal-careers-tfstate-765656213653"
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
  bucket        = "prdal-careers-seguranca-765656213653"
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
