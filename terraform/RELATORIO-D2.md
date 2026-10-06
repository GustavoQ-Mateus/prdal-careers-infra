# Ativação do demo AWS

Data: 2026-10-06. Worktree `prdal-careers-aws`, branch `impl/aws`, base `ec988a9`. Conta `765656213653`, região `us-east-1`, perfil `prdal-terraform`, identidade IAM `user/prdal-terraform`. Nenhum push desta branch foi feito.

## Base aplicada

Cada plano abaixo recebeu autorização específica do autor antes de ser aplicado. Os planos e states locais são ignorados pelo Git. O state remoto usa criptografia, versionamento e lock nativo do S3.

| Etapa | Plano salvo | Resultado do apply | Prova |
|---|---|---|---|
| Bootstrap | `bootstrap/bootstrap-d2-20261006.tfplan` | 8 criados, 0 alterados, 0 destruídos | Buckets de state e segurança com AES256, versionamento e todos os bloqueios públicos; state migrado para `bootstrap/terraform.tfstate` no S3 |
| Orçamento | `envs/demo/orcamento-d2-20261006.tfplan` | 1 criado, 0 alterados, 0 destruídos | Limite bruto de US$ 100/mês, créditos excluídos e cinco notificações conferidas pela CLI |
| Base | `envs/demo/base-d2-20261006.tfplan` | 66 criados, 0 alterados, 0 destruídos | `fmt` e `validate` passaram; plano autenticado posterior retornou código 0 e `No changes` |

O orçamento tem alertas de gasto real em 25%, 50%, 80% e 100%, e de previsão em 100%. O destinatário informado pelo autor não é reproduzido neste arquivo público.

A base criou VPC em duas zonas, quatro subnets, Internet Gateway, tabelas de rotas e endpoint de gateway do S3, sem NAT. O RDS `prdal-demo-postgres` está `available`, PostgreSQL 16.13, `db.t4g.micro`, single-AZ, 20 GB gp3 criptografados, privado e com sete dias de backup. O segredo mestre gerenciado pelo RDS está ativo.

O bucket `prdal-careers-demo-artefatos-765656213653` tem bloqueio público, AES256 e versionamento. As filas `prdal-demo-jobs` e `prdal-demo-jobs-dlq` usam criptografia gerenciada; a política envia à DLQ após três recebimentos. O cluster `prdal-demo` está ativo, com Fargate e Fargate Spot, sem serviços nem tarefas nesta etapa.

Foram criados sete ECRs `prdal-demo/<unidade>`, com scan na publicação e retenção de vinte imagens, e dez papéis OIDC `prdal-demo-publicar-<unidade>`. Cada produtor publica somente no próprio ECR. Os papéis de web, contracts e infra ainda não têm políticas de acesso a recursos.

JWT e token interno foram gerados pelo Terraform. Os segredos Anthropic e URL do banco para Batch nasceram sem valor. Somente metadados do segredo Anthropic foram consultados; nenhuma chave do provedor foi lida, gravada ou usada. A assinatura por e-mail do tópico SNS `prdal-demo-alertas` está `PendingConfirmation`.

## Custo atual

Estimativa bruta em `us-east-1`, com 730 horas por mês, sem créditos nem impostos. As tarifas do RDS foram consultadas no AWS Pricing pela CLI com o perfil pessoal autorizado.

| Item | Tarifa | US$/mês |
|---|---|---:|
| RDS `db.t4g.micro` PostgreSQL | US$ 0,016/h | 11,68 |
| Disco RDS gp3, 20 GB | US$ 0,115/GB-mês | 2,30 |
| Cinco segredos, incluindo o mestre RDS | US$ 0,40/segredo-mês | 2,00 |
| Subtotal fixo estimado | | 15,98 |

Isso representa aproximadamente US$ 0,53/dia. Com imagens, objetos e requisições em uso leve, a referência é US$ 17 a 22/mês. Orçamento e buckets vazios não têm custo fixo. Consumo de CPU acima da franquia do RDS, cópias excedentes, tráfego e chamadas aos serviços acrescentam custo. O demo completo ainda não está ligado e seu custo final não foi validado.

Fontes: [RDS PostgreSQL](https://aws.amazon.com/rds/postgresql/pricing/), [Secrets Manager](https://aws.amazon.com/secrets-manager/pricing/), [ECR](https://aws.amazon.com/ecr/pricing/), [S3](https://aws.amazon.com/s3/pricing/) e [AWS Budgets](https://aws.amazon.com/aws-cost-management/aws-budgets/pricing/).

## Validação e limites

`base-verificada-d2-20261006.tfplan` e seu log em `envs/demo/` registram o plano autenticado sem diferenças após o apply. A CLI confirmou RDS disponível e privado, zero NAT, S3 privado, cluster sem tarefas e metadados do segredo Anthropic sem versão. As suítes locais executadas anteriormente passaram em quinze cenários Terraform mockados e seis cenários PowerShell; não substituem o smoke test real e não foram repetidas nesta etapa sem mudança de configuração.

Nenhum destroy, migração de banco, acesso ao banco local do autor ou chamada real ao modelo foi executado. O demo ainda não tem URL pública. A ativação dos serviços e executores depende da publicação das imagens e de novo plano aprovado. Os scripts `subir.ps1` e `destruir.ps1` ainda precisam receber a integração dos serviços, executores e limpeza dos agendamentos antes de provar o ciclo completo da CA196.
