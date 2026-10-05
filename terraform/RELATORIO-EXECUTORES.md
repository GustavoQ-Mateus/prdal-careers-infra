# Entrega dos espelhos e executores AWS

Data: 2026-10-05. Worktree `prdal-careers-aws`, branch `impl/aws`, base `80fdd4b`. Implementação em `d518f6b`. Nenhum merge na main, push da branch, apply, destroy, chamada real a modelo ou acesso a banco foi feito. As publicações GitHub foram exclusivamente as sincronizações de espelhos autorizadas.

## Espelhos

`G:\Dev\Projetos\Prdal\repos\sincronizar.ps1` executou com sucesso para os dez espelhos a partir da main `80fdd4b`. Os dois novos são públicos e preservam o histórico filtrado, sem commit direto. O script verifica o histórico antes de criar ou publicar, cria espelhos ausentes e permite somente avanços rápidos. A conta ativa foi restaurada para `Gustavo-QMateus`. As cópias locais também receberam somente avanços rápidos; os dois novos foram clonados na mesma pasta.

| Repositório | Commits | Hash |
|---|---:|---|
| [prdal-careers-web](https://github.com/GustavoQ-Mateus/prdal-careers-web) | 116 | `1c8ed80` |
| [prdal-careers-api](https://github.com/GustavoQ-Mateus/prdal-careers-api) | 126 | `a7bb62d` |
| [prdal-careers-ai-service](https://github.com/GustavoQ-Mateus/prdal-careers-ai-service) | 98 | `64abe50` |
| [prdal-careers-doc-service](https://github.com/GustavoQ-Mateus/prdal-careers-doc-service) | 9 | `b91dc30` |
| [prdal-careers-worker](https://github.com/GustavoQ-Mateus/prdal-careers-worker) | 18 | `3c966ae` |
| [prdal-careers-batch-migrar-arquivos-s3](https://github.com/GustavoQ-Mateus/prdal-careers-batch-migrar-arquivos-s3) | 1 | `ab27950` |
| [prdal-careers-batch-reprocessar-keywords](https://github.com/GustavoQ-Mateus/prdal-careers-batch-reprocessar-keywords) | 1 | `a12ad0f` |
| [prdal-careers-lambda-enviar-lembrete](https://github.com/GustavoQ-Mateus/prdal-careers-lambda-enviar-lembrete) | 1 | `2c3aa6e` |
| [prdal-careers-contracts](https://github.com/GustavoQ-Mateus/prdal-careers-contracts) | 4 | `d31eb1c` |
| [prdal-careers-infra](https://github.com/GustavoQ-Mateus/prdal-careers-infra) | 53 | `eacbb0d` |

A primeira passagem parou na consulta de um repositório ausente pelo tratamento de stderr do PowerShell; a consulta passou a usar a lista de repositórios pessoais. A limpeza temporária ganhou repetição limitada após um bloqueio de arquivo do Windows. A passagem seguinte parou em `infra`, porque o relatório anterior descrevia literalmente os padrões de chave. A inspeção do histórico identificou somente texto documental em `44a7538`, sem credencial. O detector passou a exigir os formatos de chave, preservando a verificação de `.env` real e chave AWS. A terceira passagem terminou com código zero e publicou infra por avanço rápido. Nenhuma chave ou arquivo de ambiente real foi publicado.

O script fica fora do monorepo, portanto sua alteração não tem commit neste worktree. Os commits novos desta branch ainda não estão no espelho infra; serão levados pela sincronização após o merge do orquestrador.

## Implementação

| Item | Commit | Arquivos relativos a `infra/terraform/` | Prova |
|---|---|---|---|
| ECR e OIDC dos dois novos espelhos | `d518f6b` | `envs/demo/base.tf`, `tests/base.tftest.hcl` dentro de `envs/demo` | plano simulado exige sete imagens e dez papéis |
| Lambdas por passo e lembrete | `d518f6b` | `modules/lambda/main.tf`, `envs/demo/executores.tf` | plano simulado verifica cinco passos, lembrete, ARNs de segredo, IAM e alarmes |
| Batch por job | `d518f6b` | `modules/batch/main.tf`, `envs/demo/executores.tf` | plano simulado verifica Fargate, dois jobs, papéis separados, EFS somente leitura e IP de saída |
| Scheduler e papel | `d518f6b` | `modules/scheduler/main.tf`, `envs/demo/executores.tf` | plano simulado verifica confiança em conta/grupo, alvo único e escopo `acao-*` |
| Contratos e requisitos de ativação | `d518f6b` | `envs/demo/tests/executores.tftest.hcl` | plano integrado e rejeição esperada sem leitor de segredo por ARN |

Os detalhes de configuração estão no [README](README.md). Os módulos não lêem valores de segredo. Batch injeta valores pelo runtime Fargate; Lambda recebe ARN para leitura pela aplicação. Nenhuma chave de longa duração foi introduzida no GitHub.

## Planos e suítes

Antes da primeira consulta, STS com `--profile prdal-gustavo` confirmou a conta `765656213653`. O ARN retornou root. Todas as consultas AWS e execuções Terraform autenticadas desta sessão usaram exclusivamente esse perfil. Nenhum recurso AWS foi criado nesta sessão.

O bucket remoto de state ainda não existe e o ECR retornou zero repositórios. Para planejar sem aplicar o bootstrap, foi criada uma cópia temporária exclusiva em `C:\Users\gusta\AppData\Local\Temp\prdal-aws-plan-2btuomr_\terraform`, sem state, tfvars ou arquivos ignorados do autor. Somente nessa cópia o backend S3 foi retirado, para usar state local vazio. A configuração versionada continua com backend S3. O e-mail informado foi usado como argumento do plano, sem ser gravado no código público.

| Verificação | Resultado |
|---|---|
| `terraform fmt -check -recursive infra/terraform` | passou |
| Bootstrap e demo, `terraform validate` | passaram |
| `terraform test`, providers simulados e operação plan | 15 passaram, 0 falharam |
| Scripts do ciclo demo, AWS e Terraform simulados | 6 cenários passaram |
| Parser do script de sincronização | passou |
| Sincronização dos dez espelhos | passou, código zero |
| `git diff --check`, comentários e U+2014 nos arquivos novos de código | passou |
| Bootstrap autenticado salvo | 8 criam, 0 mudam, 0 destroem |
| Orçamento autenticado salvo | 1 cria, 0 muda, 0 destrói |
| Base autenticada salva | 67 criam, 0 mudam, 0 destroem |

Arquivos de plano nessa cópia: `bootstrap/bootstrap.tfplan`, `envs/demo/orcamento.tfplan` e `envs/demo/base.tfplan`. Logs em `bootstrap.log`, `orcamento.log` e `base.log` na raiz temporária. São planos de revisão com state local vazio, não planos para aplicar no backend remoto. Após o bootstrap aprovado, a migração de state e os planos seguintes precisam ser refeitos no backend S3, na ordem bootstrap, orçamento, base.

O plano autenticado de base usa `imagens_executores={}` e NÃO cria Lambdas, compute environment Batch, definições de job ou papel Scheduler. O plano integrado desses recursos passou somente com providers mockados. Não existe plano autenticado completo de ativação dos executores nesta entrega.

## Custo

Mantido orçamento bruto de US$ 100/mês, com os cinco alertas anteriores. Bootstrap vazio e orçamento não acrescentam custo fixo de computação. A base permanece perto da estimativa anterior de US$ 17 a 22/mês, acrescida de aproximadamente US$ 0,40/mês pelo novo segredo vazio `BATCH_DATABASE_URL`, armazenamento de imagens e uso de SNS. [Secrets Manager](https://aws.amazon.com/secrets-manager/pricing/).

Quando ativados, os doze alarmes Lambda representam cerca de US$ 1,20/mês antes de franquias. Lambda x86 cobra cerca de US$ 0,0000166667/GB-segundo e US$ 0,20 por milhão de requisições, antes de franquias. Como hipótese, 1.000 execuções de IA de 60 segundos em 1 GB custariam aproximadamente US$ 1 em computação. [CloudWatch](https://aws.amazon.com/cloudwatch/pricing/), [Lambda](https://aws.amazon.com/lambda/pricing/).

Batch não tem tarifa adicional de serviço: tarefas são cobradas pelo Fargate, com IPv4 enquanto executam, além de logs, dados e tokens. EFS não é criado nesta entrega; provisioná-lo para os arquivos legados acrescentará armazenamento e eventual tráfego. O orçamento gera alertas, não interrompe consumo. [Batch](https://aws.amazon.com/batch/faqs/), [Fargate](https://aws.amazon.com/fargate/pricing/).

## Pendências e desvios

- Publicar as quatro imagens por digest. O ECR consultado estava vazio.
- Implementar no ai-service a leitura de `ANTHROPIC_API_KEY_ARN` em runtime, sem passar o valor pelo Terraform. Essa mudança pertence à frente de aplicação; a ativação atual é rejeitada sem a confirmação `lambda_segredos_por_arn=true`.
- Preencher `BATCH_DATABASE_URL` pelo autor no Secrets Manager, definir URL interna do ai-service e liberar HTTP somente do security group Batch no serviço de IA.
- Preparar origem EFS com os arquivos legados, access point, mount targets e permissões de leitura. A migração não pode usar o volume local do compose no Fargate.
- O Scheduler utiliza o grupo `default` porque o worker omite `GroupName`. Não foi criado outro grupo sem consumidor. A limpeza dos agendamentos dinâmicos ao destruir o demo depende de parar o worker e remover somente seus alvos; o script anterior não faz essa limpeza.
- O lembrete segue o compose em modo log. Envio SES real exige identidade verificada, remetente e política específica; nada foi enviado.
- A conta tem cota Lambda de 10 execuções simultâneas. Usa-se concorrência compartilhada, sem a reserva de duas por função do desenho inicial. Reservas positivas dependem de cota suficiente.
- Os serviços ECS ainda não estão instanciados. As saídas de ambiente e política do worker precisam ser ligadas ao seu módulo na frente de deploy. Papéis OIDC publicam imagens; atualização de funções e rollback via CI seguem pendentes.
- O tópico SNS exige confirmação da assinatura por e-mail após apply. Alarmes restantes da CA168 dependem dos serviços e da telemetria e não foram considerados entregues.
- O domínio padrão do CloudFront foi aceito. A borda não foi ativada; a origem HTTPS do módulo ALB ainda precisa de uma solução de certificado sem domínio próprio.
- Nenhum `.env` do autor foi alterado. Futuramente, configure no ambiente do worker as variáveis da saída `ambiente_worker_executores`; a chave da IA deve ser resolvida somente no runtime.

Não há pedido de aprovação de apply dos executores nesta entrega, pois o plano completo autenticado ainda depende desses insumos. O bootstrap pode ser revisado separadamente; qualquer apply permanece sujeito ao ok específico do autor.
