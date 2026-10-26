# PRDAL Careers | infra

Infraestrutura do PRDAL Careers, plataforma que gera currículos otimizados para ATS por vaga, mede score explicável e acompanha candidaturas. O projeto é dividido em um repositório por unidade; este reúne o ambiente local completo e a infraestrutura AWS em Terraform.

## Repositórios do projeto

| Unidade | Stack | Papel |
|---|---|---|
| [prdal-careers-web](https://github.com/GustavoQ-Mateus/prdal-careers-web) | React, TypeScript, Vite | Interface de oportunidades, currículos, Kanban e copiloto |
| [prdal-careers-api](https://github.com/GustavoQ-Mateus/prdal-careers-api) | NestJS, TypeScript | Autenticação, regras, PostgreSQL com pgvector e migrações, publicação de jobs |
| [prdal-careers-worker](https://github.com/GustavoQ-Mateus/prdal-careers-worker) | Node, TypeScript | Consumo de jobs do SQS com lease, retentativas e fila de mensagens mortas |
| [prdal-careers-ai-service](https://github.com/GustavoQ-Mateus/prdal-careers-ai-service) | Python, FastAPI | Keywords, geração de currículo, score ATS e RAG |
| [prdal-careers-doc-service](https://github.com/GustavoQ-Mateus/prdal-careers-doc-service) | C#, .NET 10 | Renderização de DOCX e PDF |
| [prdal-careers-contracts](https://github.com/GustavoQ-Mateus/prdal-careers-contracts) | OpenAPI, TypeScript, Prisma | Contratos versionados entre os serviços |
| [prdal-careers-batch-reprocessar-keywords](https://github.com/GustavoQ-Mateus/prdal-careers-batch-reprocessar-keywords) | TypeScript | Job batch de reprocessamento de keywords |
| [prdal-careers-batch-migrar-arquivos-s3](https://github.com/GustavoQ-Mateus/prdal-careers-batch-migrar-arquivos-s3) | TypeScript | Job batch de migração de arquivos para S3 |
| [prdal-careers-lambda-enviar-lembrete](https://github.com/GustavoQ-Mateus/prdal-careers-lambda-enviar-lembrete) | TypeScript, AWS Lambda | Envio de lembretes por SES |

## Ambiente local

`docker-compose.yml` sobe todas as unidades com as dependências locais: PostgreSQL com pgvector, ElasticMQ no lugar do SQS e um S3 local. O serviço `migracao` aplica as migrações da api antes de ela subir, e cada serviço expõe `/health` e `/ready`. `docker-compose.models.yml` adiciona os modelos locais. `test/compose.test.js` valida a composição.

## AWS com Terraform

`terraform/` contém o `bootstrap` dos buckets de state, o ambiente efêmero `envs/demo` e os módulos de rede, ALB, ECR, ECS, RDS, SQS, S3, Lambda, AWS Batch, Scheduler, segredos, CDN, OIDC do GitHub Actions e orçamento. O ambiente sobe e é destruído por scripts que fazem snapshot e restauram os dados. Detalhes de operação em [terraform/README.md](terraform/README.md).

## CI

O workflow `ci.yml` roda `terraform fmt` e `validate` em cada ambiente e uma verificação de texto do repositório.
