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

## Variáveis dos espelhos

`AWS_ROLE_ARN` foi gravado com `gh variable set` e conferido pela API em todos os dez espelhos. Cada valor corresponde ao ARN real `arn:aws:iam::765656213653:role/prdal-demo-publicar-<unidade>`, conferido no IAM. Nenhuma chave ou segredo foi colocado no GitHub.

`ECS_CLUSTER=prdal-demo` foi gravado em api, worker e ai-service. O web recebeu `VITE_API_URL=/api`. A conta pessoal `GustavoQ-Mateus` foi usada para as gravações e a conta `Gustavo-QMateus` foi restaurada no `finally`.

`ECS_SERVICE`, `ECS_CONTAINER`, `LAMBDA_FUNCTION_NAME`, `BATCH_JOB_DEFINITION`, o bucket web e o ID da distribuição CloudFront ainda dependem dos recursos da próxima etapa. Não foram usados nomes de recursos inexistentes. Os papéis foram configurados enquanto o RDS concluía, pois já existiam; a conferência final da base foi feita após o apply completo.

## Primeira publicação e bloqueios para o orquestrador

Os dez CIs foram disparados novamente na `main` pela reexecução completa dos runs, depois de configurar os papéis. Os workflows não oferecem `workflow_dispatch`. A tentativa 2 terminou com um sucesso e nove falhas. Os sete ECRs foram consultados individualmente e todos têm zero imagens. A publicação não foi considerada concluída.

| Espelho | CI da tentativa 2 | Resultado |
|---|---|---|
| web | [37407904385](https://github.com/GustavoQ-Mateus/prdal-careers-web/actions/runs/37407904385) | Falha no teste de refresh entre abas: duas chamadas onde se esperava uma |
| api | [37407914552](https://github.com/GustavoQ-Mateus/prdal-careers-api/actions/runs/37407914552) | Scan: 55 HIGH e 4 CRITICAL no SO; 11 HIGH nas bibliotecas |
| ai-service | [37406111675](https://github.com/GustavoQ-Mateus/prdal-careers-ai-service/actions/runs/37406111675) | Scan: 45 HIGH no SO e 3 HIGH nas bibliotecas |
| doc-service | [37394292279](https://github.com/GustavoQ-Mateus/prdal-careers-doc-service/actions/runs/37394292279) | Verificação passou; publicação falhou em `sts:AssumeRoleWithWebIdentity` |
| worker | [37406127692](https://github.com/GustavoQ-Mateus/prdal-careers-worker/actions/runs/37406127692) | Scan: 55 HIGH e 4 CRITICAL no SO; 11 HIGH nas bibliotecas |
| batch-migrar-arquivos-s3 | [37397260917](https://github.com/GustavoQ-Mateus/prdal-careers-batch-migrar-arquivos-s3/actions/runs/37397260917) | Scan: 55 HIGH e 4 CRITICAL no SO; 11 HIGH nas bibliotecas |
| batch-reprocessar-keywords | [37397271987](https://github.com/GustavoQ-Mateus/prdal-careers-batch-reprocessar-keywords/actions/runs/37397271987) | Scan: 55 HIGH e 4 CRITICAL no SO; 11 HIGH nas bibliotecas |
| lambda-enviar-lembrete | [37394337575](https://github.com/GustavoQ-Mateus/prdal-careers-lambda-enviar-lembrete/actions/runs/37394337575) | Scan: 8 HIGH no SO e 22 HIGH nas bibliotecas |
| contracts | [37407966054](https://github.com/GustavoQ-Mateus/prdal-careers-contracts/actions/runs/37407966054) | Passou |
| infra | [37394361975](https://github.com/GustavoQ-Mateus/prdal-careers-infra/actions/runs/37394361975) | Terraform 1.10.5 no CI é incompatível com o requisito `>= 1.15` |

Os logs completos das nove falhas ficam localmente nesta pasta como `ci-d2-<unidade>-<run>-tentativa2.log`, ignorados pelo Git. As correções dos aplicativos e workflows passam pelo orquestrador; nenhum scan foi desativado nem relativizado.

Além dessas falhas, os sete workflows de imagem precisam publicar em `prdal-demo/<unidade>`, como definido pelos ECRs e IAM. Atualmente `ECR_REPOSITORIO` tem somente o nome da unidade. Eles também usam `--profile prdal-gustavo` sem preparar esse perfil temporário no runner, diferentemente do workflow web; o input `aws-profile` do configure-aws-credentials pode preparar o perfil com as credenciais temporárias OIDC. A tag fixa `latest` não combina com atualizações repetidas nos ECRs imutáveis; a tag do commit pode servir como referência. A doc-render precisa usar `Dockerfile.lambda`, pois o Dockerfile padrão publica a versão HTTP. O primeiro CI deve conseguir publicar a imagem antes da existência do serviço ou função; o rollout e suas permissões entram depois da criação dos destinos.

## Correção da confiança OIDC preparada

A API `actions/oidc/customization/sub` confirmou `use_immutable_subject=true` e o prefixo real em todos os dez espelhos. O dono tem ID `199433320`; cada repositório tem seu ID próprio. O IAM aplicado usa o formato antigo sem IDs, portanto o subject não corresponde. Essa causa é consistente com a falha da doc-service e está documentada no [configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials#immutable-subject-claims).

O módulo agora exige IDs numéricos e usa `StringEquals` no subject completo, restrito à `main` do espelho e à audiência STS. Não aceita subjects antigos nem curingas. Os IDs conferidos foram registrados em `envs/demo/oidc.tf`. Os testes verificam os subjects de Batch e web, audiência e escopo ECR, e rejeitam repositório sem ID.

O plano autenticado salvo `envs/demo/oidc-d2-20261006.tfplan` contém 0 criações, 10 alterações e 0 destruições. A revisão do JSON confirmou somente mudanças de `assume_role_policy` nos dez papéis existentes. O custo adicional estimado é US$ 0; o custo corrente da base permanece o da tabela acima. A correção ainda não está aplicada e continua sujeita ao ok específico do autor. Depois da aprovação, a doc-service pode ser reexecutada para provar a assunção do papel; os bloqueios de aplicação acima permanecem com o orquestrador.

Validação desta correção: `fmt -check -recursive`, `validate`, dezesseis testes Terraform com providers mockados, seis cenários PowerShell e verificação de texto passaram. `git diff --check` passou. Nenhuma configuração dos serviços de aplicação ou workflow foi alterada nesta branch.

Arquivos da correção: `modules/github-oidc/main.tf`, `envs/demo/oidc.tf`, `envs/demo/tests/base.tftest.hcl`, `README.md` e este relatório. Os registros das etapas anteriores estão nos commits `dc9fb60` (applies da base) e `cd0b454` (variáveis dos espelhos).
