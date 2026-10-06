variable "nome" { type = string }
variable "vpc_id" { type = string }
variable "subnets_publicas" { type = list(string) }
variable "certificado_arn" {
  type    = string
  default = null
}
variable "cloudfront_prefix_list_id" {
  type    = string
  default = null
}
variable "origin_header_value" {
  type      = string
  default   = null
  sensitive = true
}
variable "origin_header_habilitado" {
  type    = bool
  default = false
}

resource "aws_security_group" "alb" {
  name_prefix = "${var.nome}-alb-"
  vpc_id      = var.vpc_id
  dynamic "ingress" {
    for_each = var.certificado_arn == null ? [] : [1]
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  dynamic "ingress" {
    for_each = var.certificado_arn == null ? [1] : []
    content {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      prefix_list_ids = [var.cloudfront_prefix_list_id]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "principal" {
  name               = var.nome
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnets_publicas
  idle_timeout       = 120
}

resource "aws_lb_target_group" "api" {
  name        = "${var.nome}-api"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check {
    path                = "/ready"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

resource "aws_lb_listener" "https" {
  count             = var.certificado_arn == null ? 0 : 1
  load_balancer_arn = aws_lb.principal.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificado_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_lb_listener" "http" {
  count             = var.certificado_arn == null ? 1 : 0
  load_balancer_arn = aws_lb.principal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "cloudfront" {
  count        = var.certificado_arn == null && var.origin_header_habilitado ? 1 : 0
  listener_arn = aws_lb_listener.http[0].arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    http_header {
      http_header_name = "X-Prdal-Origin-Token"
      values           = [var.origin_header_value]
    }
  }
}

output "dns" { value = aws_lb.principal.dns_name }
output "target_group_arn" { value = aws_lb_target_group.api.arn }
output "security_group_id" { value = aws_security_group.alb.id }
