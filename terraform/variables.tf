variable "project" {
  type    = string
  default = "prdal-careers"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "db_username" {
  type    = string
  default = "prdal"
}

variable "db_password" {
  type      = string
  sensitive = true
}
