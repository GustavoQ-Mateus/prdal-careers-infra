variable "nome" { type = string }
variable "vpc_id" { type = string }
variable "subnets_publicas" { type = list(string) }
variable "certificado_arn" { type = string }

resource "aws_security_group" "alb" {
  name_prefix = "${var.nome}-alb-"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

output "dns" { value = aws_lb.principal.dns_name }
output "target_group_arn" { value = aws_lb_target_group.api.arn }
output "security_group_id" { value = aws_security_group.alb.id }
