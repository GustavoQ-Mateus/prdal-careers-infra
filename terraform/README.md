# Terraform stub, alvo AWS

Stub descrevendo o alvo de deploy: ECS (os quatro serviços), RDS PostgreSQL e DocumentDB (compatível com MongoDB). Não é aplicado em nenhuma pipeline da Fase 0, serve para documentar a topologia de produção pretendida.

```bash
terraform init
terraform plan -var "db_password=..."
```
