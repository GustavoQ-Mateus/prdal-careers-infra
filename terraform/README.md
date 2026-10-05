# Infraestrutura AWS

`bootstrap/` cria os buckets persistentes de state e cópia de segurança. `envs/demo/` contém o ambiente efêmero. `modules/` contém as unidades de rede, dados, fila, segredos, imagens, cluster, OIDC e borda. O perfil `prod` será definido após a validação do `demo`; ele usará tarefas em subnets privadas, NAT e maior retenção de backup.

Região: `us-east-1`. Conta: `765656213653`. Perfil CLI e Terraform: `prdal-terraform`. Todo comando Terraform deve definir `AWS_PROFILE=prdal-terraform` explicitamente.

Ordem de operação: bootstrap, orçamento e base do `demo`. Cada `apply` exige `fmt -check`, `validate`, plano salvo, apresentação do resumo e custo ao autor e aprovação específica. Os scripts em `envs/demo/` fazem snapshot e cópia dos dados antes de destruir e restauram na próxima subida.

## Preparação

O perfil `prdal-terraform` deve apontar para `arn:aws:iam::765656213653:user/prdal-terraform`. O autor cria e configura a chave no próprio terminal. Os providers recusam outra conta e os scripts também verificam o ARN. Nunca use os perfis corporativos.

Os arquivos de state, planos e variáveis locais são ignorados. Os lockfiles dos providers são versionados. Nenhuma senha entra como variável: o RDS administra a senha mestre, e o Terraform gera `JWT_SECRET` e `SERVICE_TOKEN` de 48 caracteres. O segredo `ANTHROPIC_API_KEY` nasce sem valor. Depois de cada recriação, o autor grava a chave por CLI no próprio terminal; ela nunca deve entrar no repositório, nos comandos do agente nem nos relatórios.

## Bootstrap e orçamento

A partir desta pasta, no PowerShell:

```powershell
$env:AWS_PROFILE = 'prdal-terraform'
terraform -chdir=bootstrap init
terraform -chdir=bootstrap fmt -check
terraform -chdir=bootstrap validate
terraform -chdir=bootstrap plan -out=bootstrap.tfplan
terraform -chdir=bootstrap show bootstrap.tfplan
```

Após apresentar o plano e o custo e receber autorização para esse plano:

```powershell
$env:AWS_PROFILE = 'prdal-terraform'
terraform -chdir=bootstrap apply bootstrap.tfplan
Copy-Item bootstrap/backend-remoto.tf.example bootstrap/backend-remoto.tf
terraform -chdir=bootstrap init -migrate-state
```

O bootstrap começa com state local porque o bucket ainda não existe. A migração leva o state do próprio bootstrap ao S3 com lock nativo. Preserve o state local até conferir a migração. Os dois buckets usam versionamento, AES256, bloqueio público e `prevent_destroy`; ficam fora do ciclo do `demo`.

O primeiro plano do `demo` contém somente o orçamento:

```powershell
$env:AWS_PROFILE = 'prdal-terraform'
terraform -chdir=envs/demo init
terraform -chdir=envs/demo fmt -check
terraform -chdir=envs/demo validate
terraform -chdir=envs/demo plan -var='email_orcamento=orcamento@example.invalid' -var='limite_mensal=100' -var='habilitar_base=false' -out=orcamento.tfplan
terraform -chdir=envs/demo show orcamento.tfplan
```

Substitua o e-mail pelo informado pelo autor no terminal. Ele é variável comum e fica no state, nunca em arquivo versionado. Aplique o plano somente após apresentar seu custo e obter autorização específica. O orçamento acompanha o gasto bruto da conta, sem créditos nem reembolsos, e notifica gasto real em 25%, 50%, 80% e 100%, e previsão em 100%. Alertas de orçamento são gratuitos; eles não interrompem automaticamente o consumo. [Preço do AWS Budgets](https://aws.amazon.com/aws-cost-management/aws-budgets/pricing/).

## Ciclo do demo

```powershell
.\envs\demo\subir.ps1 -Ambiente demo -EmailOrcamento 'orcamento@example.invalid'
.\envs\demo\subir.ps1 -Ambiente demo -EmailOrcamento 'orcamento@example.invalid' -Executar
.\envs\demo\destruir.ps1 -Ambiente demo -EmailOrcamento 'orcamento@example.invalid'
.\envs\demo\destruir.ps1 -Ambiente demo -EmailOrcamento 'orcamento@example.invalid' -Executar
```

Sem `-Executar`, os scripts apenas mostram o plano e o custo. Com a opção, ainda exigem confirmação para o plano salvo. Use o mesmo `-LimiteMensal` caso altere o padrão de US$ 100.

`subir.ps1` exige que o orçamento já exista. Consulta o manifesto de segurança e restaura banco e artefatos somente quando esses recursos ainda não estão no state. A subida repetida conserva os dados ativos. A migração da api cria `vector`; o Terraform não conecta ao banco nem executa DDL.

`destruir.ps1` planeja `habilitar_base=false`, preservando o orçamento gratuito. Antes de aplicar a remoção, cria um snapshot manual datado, aguarda sua disponibilidade, copia os artefatos para um prefixo associado ao snapshot e grava `demo/restauracao.json` no bucket de segurança. Qualquer falha interrompe a remoção. Um state parcial dos recursos de dados também interrompe a operação para evitar perda. O bucket versionado do ambiente e os ECRs permitem remoção completa do conteúdo após o backup.

Ficam somente os buckets de state e segurança, seus objetos e versões, os snapshots manuais, o orçamento e o usuário IAM de administração. Snapshots e cópias antigos são mantidos até o autor definir a retenção. O RDS elimina backups automáticos ao ser removido. Nenhuma tarefa, ALB, NAT, IP público ou banco provisionado permanece após a remoção da base.

## Estimativa de custo

Valores de referência em `us-east-1`, 730 horas por mês, antes de créditos, impostos e tráfego variável. Reconfirme os preços ao apresentar cada plano.

| Escopo | Estimativa mensal |
|---|---|
| Bootstrap vazio | sem custo fixo; S3 e requisições por uso |
| Orçamento de alertas | US$ 0 |
| Base desta entrega, sem serviços nem ALB | cerca de US$ 17 a 22 |
| Demo completo previsto no desenho | cerca de US$ 105 a 115, mais tokens e tráfego |
| Segurança após remover a base | S3 cerca de US$ 0,023/GB-mês; snapshots cerca de US$ 0,095/GB-mês |

A base considera RDS pequeno com 20 GB e quatro segredos, incluindo o gerenciado pelo RDS. Secrets Manager cobra US$ 0,40 por segredo-mês, proporcional ao período, mais chamadas. [Preço do Secrets Manager](https://aws.amazon.com/secrets-manager/pricing/).

O desenho estima US$ 87 a 93 por mês para o demo completo. Cinco IPv4 públicos, três tarefas e duas zonas do ALB, acrescentam aproximadamente US$ 18,25 por mês a US$ 0,005/IP-hora. Assim, US$ 200 duram aproximadamente 53 a 58 dias com todo o demo ligado; com a referência antiga de US$ 90, seriam cerca de 68 dias. São estimativas: tokens, impostos, tráfego, imagens e cópias adicionais reduzem esse prazo. [Preço de IPv4 público](https://aws.amazon.com/vpc/pricing/).

Um snapshot de 20 GB representa aproximadamente US$ 1,90/mês após remover o banco; 1 GB de cópias no S3 acrescenta cerca de US$ 0,023/mês, além de versões e requisições. Snapshots são incrementais e o tamanho faturado depende dos dados e das gerações preservadas. [Exemplo de preço de backup RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithReservedDBInstances.html), [referência de S3 Standard](https://docs.aws.amazon.com/solutions/latest/live-streaming-on-aws-with-amazon-s3/live-streaming-on-aws-with-amazon-s3.pdf).

## Borda e permissões de publicação

Os módulos `alb`, `cdn` e `ecs-service` têm planos simulados em `envs/demo/tests/borda.tftest.hcl` e não são instanciados na base. Dependem de imagens publicadas e certificados. Mesmo usando o domínio padrão do CloudFront no navegador, a origem HTTPS do ALB precisa de domínio e certificado válidos; o domínio AWS do ALB não pode receber um certificado ACM da conta. Essa escolha permanece com o autor.

O ALB tem HTTPS, `/ready` e idle de 120 s. A CDN mantém S3 privado com OAC, `/api/*` sem cache e origem HTTPS com read/keepalive de 60 s. O serviço ECS tem papéis separados, segredos por ARN, logs, rollback, Fargate ou Spot e autoscaling opcional. O chamador fornece os security groups com entrada somente do ALB e dos serviços autorizados, as variáveis e as políticas de tarefa.

Todos os dez espelhos têm papel OIDC restrito à `main` da conta `GustavoQ-Mateus`. Os sete produtores de imagem publicam somente no próprio ECR. Os papéis de web, contracts e infra ainda não recebem políticas de acesso. A permissão `ecr:GetAuthorizationToken` usa `*`, como exige a API; as ações de publicação usam somente o ARN do ECR correspondente. Jobs Batch seguem `prdal-careers-batch-<nome>` no GitHub e `batch-<nome>` no ECR e no papel.

Os módulos `lambda`, `batch` e `scheduler` estão integrados em `envs/demo/executores.tf`. A base cria os sete ECRs, dez papéis OIDC, tópico SNS com assinatura no e-mail de orçamento e o segredo vazio `BATCH_DATABASE_URL`. O e-mail entra por variável, sem valor pessoal versionado. O limite mensal continua US$ 100. Nenhuma chamada ao modelo de linguagem faz parte destas validações.

`imagens_executores` vazio prepara somente a base. Para habilitar os executores, informe as quatro imagens por digest no ECR pessoal: `ai-service`, `lambda-enviar-lembrete`, `batch-migrar-arquivos-s3` e `batch-reprocessar-keywords`. O ai-service fornece cinco funções, com o comando `app.lambda_handler.handler`: rascunho, verificar, reparar, montar e keywords. A imagem própria do lembrete usa `dist/lembrete.handler`. As funções ficam fora da VPC, com timeout de 120 segundos na IA e 30 no lembrete, logs por sete dias e alarmes de erro e throttling via SNS. A cota da conta consultada foi 10 execuções simultâneas; o padrão usa concorrência compartilhada (`-1`), sem reserva ou provisionamento. O módulo aceita reserva positiva quando a cota permitir.

A chave da IA entra somente como `ANTHROPIC_API_KEY_ARN`, com permissão de leitura restrita ao segredo. A imagem atual só lê `ANTHROPIC_API_KEY`; a frente de aplicação precisa adicionar leitura por ARN no runtime antes de marcar `lambda_segredos_por_arn=true`. O Terraform não busca o valor da chave. Os digests de teste são fictícios e aparecem somente nos planos simulados.

O Batch usa Fargate em subnets públicas com IP para saída, sem NAT nem entrada pública, máximo de duas vCPUs e um papel de execução e de tarefa por job. Os segredos são injetados pelo Fargate por ARN. O autor precisa preencher `BATCH_DATABASE_URL` no Secrets Manager, com uma URL de acesso ao RDS, sem passar o valor pelo Terraform. Reprocessamento usa a base direta `https://api.anthropic.com`, `LOTES_MODO=anthropic` e exige `ai_service_url` alcançável pelas tarefas, com entrada no security group do ai-service autorizada para o security group Batch. As saídas do módulo permitem essa ligação quando os serviços ECS forem instanciados.

A migração exige `arquivos_efs` com filesystem, access point, ARN e security group existentes, contendo os arquivos legados e mount targets acessíveis. O volume `apistorage` do compose não existe no Fargate. O módulo monta EFS com TLS e IAM em `/app/storage`, somente leitura, e libera NFS apenas do security group Batch. A política concede montagem somente pelo access point informado; configure também as permissões POSIX de leitura. EFS e a transferência dos arquivos não são criados nesta entrega.

O worker atual omite `GroupName`: o Scheduler usa o grupo AWS `default`, já existente. O Terraform cria o papel, com confiança na conta e no ARN desse grupo, e permissão de invocar somente a Lambda de lembrete. `politica_worker_executores` concede gerenciamento somente de `schedule/default/acao-*`, passagem somente desse papel ao Scheduler e invocação somente das cinco funções de IA. A frente ECS deve anexar essa política ao papel do worker e injetar `ambiente_worker_executores`. Os agendamentos são criados dinamicamente pelo worker, não pelo Terraform. Antes de destruir um demo ativado, interrompa o worker e remova os agendamentos dele cujo alvo seja a Lambda desse demo; o script atual ainda não faz essa limpeza do grupo compartilhado.

O lembrete usa `REMETENTE_MODO=log`, como no compose, sem envio de e-mail real. SES com identidade verificada, `SES_ORIGEM` e política de envio restrita fica pendente. A assinatura de alertas SNS precisa da confirmação por e-mail após o apply. Alarmes restantes da CA168, implantação dos serviços ECS, CI de atualização de funções e o perfil `prod` seguem pendentes. A decisão de usar o domínio padrão do CloudFront foi registrada; a origem HTTPS do módulo ALB ainda depende de uma solução de certificado e não é instanciada aqui.

Planos autenticados de bootstrap, orçamento e base e suas limitações estão no [relatório de executores](RELATORIO-EXECUTORES.md). Os planos completos dos executores são simulados; imagens, leitura de segredo no runtime e fontes Batch devem ser resolvidas antes de planejar a ativação na conta.

## Validação local

```powershell
$env:AWS_PROFILE = 'prdal-terraform'
terraform -chdir=bootstrap init -backend=false
terraform -chdir=bootstrap validate
terraform -chdir=envs/demo init -backend=false
terraform -chdir=envs/demo validate
terraform -chdir=envs/demo test
powershell -NoProfile -ExecutionPolicy Bypass -File envs/demo/tests/scripts.Tests.ps1
```

Os testes Terraform usam providers simulados e operações `plan`; não substituem planos autenticados salvos nem uma prova real do ciclo de backup e restauração. Os testes PowerShell simulam AWS e Terraform e verificam os controles de execução e a ordem do backup.
