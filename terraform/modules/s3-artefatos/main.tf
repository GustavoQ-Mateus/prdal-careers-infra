variable "nome" {
  type = string
}

resource "aws_s3_bucket" "artefatos" {
  bucket        = var.nome
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "artefatos" {
  bucket                  = aws_s3_bucket.artefatos.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artefatos" {
  bucket = aws_s3_bucket.artefatos.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "artefatos" {
  bucket = aws_s3_bucket.artefatos.id
  versioning_configuration {
    status = "Enabled"
  }
}

output "bucket" {
  value = aws_s3_bucket.artefatos.id
}

output "arn" {
  value = aws_s3_bucket.artefatos.arn
}
