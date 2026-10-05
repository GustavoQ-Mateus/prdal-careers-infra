mock_provider "aws" {
  override_during = plan
  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::teste-web", bucket_regional_domain_name = "teste-web.s3.us-east-1.amazonaws.com" }
  }
  mock_resource "aws_cloudfront_distribution" {
    defaults = { arn = "arn:aws:cloudfront::765656213653:distribution/TESTE" }
  }
}

run "alb_https" {
  command = plan
  module { source = "../../modules/alb" }
  variables {
    nome             = "teste"
    vpc_id           = "vpc-0123456789abcdef0"
    subnets_publicas = ["subnet-0123456789abcdef0", "subnet-1123456789abcdef0"]
    certificado_arn  = "arn:aws:acm:us-east-1:765656213653:certificate/00000000-0000-0000-0000-000000000000"
  }
  assert {
    condition     = aws_lb.principal.idle_timeout == 120 && aws_lb_listener.https.protocol == "HTTPS" && aws_lb_target_group.api.health_check[0].path == "/ready"
    error_message = "O ALB precisa de HTTPS, readiness e idle de 120 segundos."
  }
}

run "cdn_mesmo_dominio" {
  command = plan
  module { source = "../../modules/cdn" }
  variables {
    nome        = "teste"
    bucket_web  = "teste-web"
    dominio_alb = "api.example.invalid"
  }
  assert {
    condition     = aws_cloudfront_distribution.principal.ordered_cache_behavior[0].path_pattern == "/api/*" && aws_cloudfront_distribution.principal.default_cache_behavior[0].target_origin_id == "web"
    error_message = "A CDN deve separar web e api pelo caminho."
  }
}

run "servico_com_rollback" {
  command = plan
  module { source = "../../modules/ecs-service" }
  variables {
    nome               = "teste"
    cluster_arn        = "arn:aws:ecs:us-east-1:765656213653:cluster/teste"
    imagem             = "765656213653.dkr.ecr.us-east-1.amazonaws.com/teste:teste"
    subnets            = ["subnet-0123456789abcdef0"]
    security_group_ids = ["sg-0123456789abcdef0"]
    porta              = 3000
    cpu                = 512
    memoria            = 1024
  }
  assert {
    condition     = aws_ecs_service.servico.deployment_circuit_breaker[0].rollback && aws_ecs_service.servico.network_configuration[0].assign_public_ip
    error_message = "O serviço demo precisa de rollback e acesso de saída sem NAT."
  }
}
