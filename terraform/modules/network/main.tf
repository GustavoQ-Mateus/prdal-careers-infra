variable "nome" {
  type = string
}

variable "nat_habilitado" {
  type    = bool
  default = false
}

data "aws_availability_zones" "disponiveis" {
  state = "available"
}

resource "aws_vpc" "principal" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.nome}-vpc"
  }
}

resource "aws_internet_gateway" "principal" {
  vpc_id = aws_vpc.principal.id
  tags = {
    Name = "${var.nome}-igw"
  }
}

resource "aws_subnet" "publica" {
  count                   = 2
  vpc_id                  = aws_vpc.principal.id
  availability_zone       = data.aws_availability_zones.disponiveis.names[count.index]
  cidr_block              = cidrsubnet(aws_vpc.principal.cidr_block, 8, count.index)
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.nome}-publica-${count.index + 1}"
  }
}

resource "aws_subnet" "privada" {
  count             = 2
  vpc_id            = aws_vpc.principal.id
  availability_zone = data.aws_availability_zones.disponiveis.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.principal.cidr_block, 8, count.index + 10)
  tags = {
    Name = "${var.nome}-privada-${count.index + 1}"
  }
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.principal.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.principal.id
  }
  tags = {
    Name = "${var.nome}-publica"
  }
}

resource "aws_route_table_association" "publica" {
  count          = 2
  subnet_id      = aws_subnet.publica[count.index].id
  route_table_id = aws_route_table.publica.id
}

resource "aws_eip" "nat" {
  count  = var.nat_habilitado ? 1 : 0
  domain = "vpc"
}

resource "aws_nat_gateway" "principal" {
  count         = var.nat_habilitado ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.publica[0].id
  depends_on    = [aws_internet_gateway.principal]
}

resource "aws_route_table" "privada" {
  vpc_id = aws_vpc.principal.id
  dynamic "route" {
    for_each = var.nat_habilitado ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.principal[0].id
    }
  }
  tags = {
    Name = "${var.nome}-privada"
  }
}

resource "aws_route_table_association" "privada" {
  count          = 2
  subnet_id      = aws_subnet.privada[count.index].id
  route_table_id = aws_route_table.privada.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.principal.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.publica.id, aws_route_table.privada.id]
}

output "vpc_id" {
  value = aws_vpc.principal.id
}

output "subnets_publicas" {
  value = aws_subnet.publica[*].id
}

output "subnets_privadas" {
  value = aws_subnet.privada[*].id
}
