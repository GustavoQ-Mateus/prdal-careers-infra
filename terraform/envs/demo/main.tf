terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    key          = "demo/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = [var.conta_aws]
  default_tags {
    tags = {
      projeto  = "prdal-careers"
      ambiente = "demo"
      dono     = "gusta"
    }
  }
}

module "orcamento" {
  source        = "../../modules/orcamento"
  email         = var.email_orcamento
  limite_mensal = var.limite_mensal
}

variable "conta_aws" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.conta_aws))
    error_message = "Informe o ID de 12 dígitos da conta AWS pessoal."
  }
}

variable "email_orcamento" {
  type = string
  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.email_orcamento))
    error_message = "Informe um e-mail válido para o orçamento."
  }
}

variable "limite_mensal" {
  type    = number
  default = 100
}

variable "habilitar_base" {
  type    = bool
  default = false
}
