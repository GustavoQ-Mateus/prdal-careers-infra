# Entrega de repositórios e base AWS

Worktree `prdal-careers-aws`, branch `impl/aws`. A frente A foi concluída antes da implementação da frente B. Nenhum `apply` ou `destroy` foi executado. Os planos autenticados e a criação dos recursos Terraform aguardam a configuração do perfil pelo autor e as aprovações específicas.

## Frente A

Todos os espelhos são públicos, com branch `main`, histórico filtrado e sem commits diretos. A mudança de nome Batch foi aplicada no GitHub, na pasta local, no remoto, no script e no Terraform; preservou o hash do espelho.

| Repositório | URL | Commits | Último hash |
|---|---|---:|---|
| web | [prdal-careers-web](https://github.com/GustavoQ-Mateus/prdal-careers-web) | 116 | `1c8ed80` |
| api | [prdal-careers-api](https://github.com/GustavoQ-Mateus/prdal-careers-api) | 120 | `c1c819c` |
| ai-service | [prdal-careers-ai-service](https://github.com/GustavoQ-Mateus/prdal-careers-ai-service) | 93 | `54dd156` |
| doc-service | [prdal-careers-doc-service](https://github.com/GustavoQ-Mateus/prdal-careers-doc-service) | 9 | `b91dc30` |
| worker | [prdal-careers-worker](https://github.com/GustavoQ-Mateus/prdal-careers-worker) | 13 | `b8af8fc` |
| batch-migrar-arquivos-s3 | [prdal-careers-batch-migrar-arquivos-s3](https://github.com/GustavoQ-Mateus/prdal-careers-batch-migrar-arquivos-s3) | 1 | `ab27950` |
| contracts | [prdal-careers-contracts](https://github.com/GustavoQ-Mateus/prdal-careers-contracts) | 4 | `d31eb1c` |
| infra | [prdal-careers-infra](https://github.com/GustavoQ-Mateus/prdal-careers-infra) | 36 | `efd13e9` |

Script entregue: `G:\Dev\Projetos\Prdal\repos\sincronizar.ps1`. Ele refaz clone e filtro, verifica arquivos de ambiente e padrões de chave, busca a `main` remota, verifica `merge-base --is-ancestor` e envia apenas avanços rápidos. A conta de trabalho do GitHub é restaurada no `finally`.

A execução inicial do script conferiu os oito hashes e terminou sem novos pushes. Após a renomeação, a sintaxe do script foi validada e o nome, a URL e a branch do repositório foram conferidos no GitHub. A pasta nova preservou exatamente `ab27950ce4fc96bf33a1948bf851d0cfbebd466f`; a cópia antiga, limpa, foi removida.

Auditoria: nenhuma ocorrência de arquivo `.env` real nem de credencial dos padrões exigidos nos históricos filtrados. Foram encontrados `.env.example` e uma coincidência de `AKIA` dentro do hash `integrity` do `package-lock.json` do web, no commit `2ed1023`. A coincidência foi classificada sem imprimir a linha. O script de sincronização verifica `sk-ant`, `sk-or-` e o formato de chave AWS `AKIA` seguido de 16 caracteres alfanuméricos maiúsculos.

## Frente B

Os caminhos da tabela são relativos a `infra/terraform/`. `plan simulado` significa operação `plan` em `terraform test` com providers mockados, sem chamadas à AWS. Não equivale a plano autenticado salvo.

| Item | Commit | Arquivos | Prova e estado |
|---|---|---|---|
| 0, usuário IAM | sem commit, CLI | nenhum arquivo de credencial | STS confirmou conta `765656213653` e root; usuário `prdal-terraform` criado com tags e `AdministratorAccess`; perfil novo ainda ausente |
| 1, limpeza | `fccda16` | remoção de `main.tf` e `variables.tf`; `README.md` | stub e DocumentDB removidos |
| 2, bootstrap | `98f791e`, `18acfaf` | `bootstrap/main.tf`, lockfile, `backend-remoto.tf.example`, `.gitignore` | `validate` passou; plano autenticado e apply pendentes |
| 3, orçamento | `0c38b24`, `4257046` | `modules/orcamento/main.tf`, `envs/demo/main.tf`, lockfile | `validate` e planos simulados da etapa isolada e dos cinco alertas passaram |
| 4, rede | `657756c` | `modules/network/main.tf`, `envs/demo/base.tf` | `validate` e plano simulado com duas zonas e zero NAT passaram |
| 5, dados | `0eb1a3a` | módulos `rds`, `s3-artefatos`, `sqs`; `envs/demo/dados.tf` | `validate`, plano simulado do banco privado e DLQ com três tentativas passaram |
| 6, segredos | `e6a2a33` | `modules/segredos/main.tf`, `envs/demo/segredos.tf` | `validate` e plano simulado da base passaram; chave externa sem versão/valor no código |
| 7, ECR e cluster | `0f647a7` | módulos `ecr`, `ecs-cluster`; `envs/demo/base.tf` | `validate` e plano simulado com as cinco imagens, incluindo `batch-migrar-arquivos-s3`, passaram |
| 8, OIDC | `371b02a` | `modules/github-oidc/main.tf`, `envs/demo/oidc.tf`, `tests/base.tftest.hcl` | plano simulado confirmou oito papéis, confiança na main Batch e publicação restrita ao ECR próprio |
| 9, ciclo demo | `c0aea1a` | `envs/demo/subir.ps1`, `destruir.ps1`, `tests/scripts.Tests.ps1` | sintaxe válida e seis cenários simulados passaram; ciclo real depende de recursos e aprovações |
| 10, borda futura | `d3561ca` | módulos `alb`, `cdn`, `ecs-service`; `tests/borda.tftest.hcl` | três planos simulados passaram; módulos não instanciados na base e não aplicados |
| 11, posteriores | sem commit | nenhum módulo criado | Lambdas, Batch, Scheduler e alarmes posteriores preservados para C3b |

## Resultado das suítes

| Verificação | Resultado |
|---|---|
| Bootstrap, Terraform 1.15.8 e AWS provider 6.67.0 | `validate` passou |
| Demo, AWS 6.67.0 e random 3.9.1 | `validate` passou |
| Terraform com operações plan e providers simulados | 10 passaram, 0 falharam |
| PowerShell com AWS e Terraform simulados | 6 cenários passaram |
| Parser PowerShell dos scripts | passou |
| Auditoria de nomes antigos, comentários em código e travessão | nenhuma ocorrência após as correções |

Os cenários PowerShell cobrem planejamento sem execução para subir e destruir, falha de snapshot impedindo a remoção, ordem de snapshot/cópia/manifesto antes da remoção, subida repetida preservando dados ativos e restauração de banco e artefatos em uma nova subida. Não houve chamada real a modelo de linguagem nem a banco.

## Recursos e custo

Criado na conta: usuário IAM `prdal-terraform`, com `AdministratorAccess` e tags `projeto`, `ambiente`, `dono`. Nenhuma chave foi criada pelo agente. Nenhum recurso Terraform foi aplicado; a transição de identidade ainda depende do autor.

As estimativas e as fontes estão no [README](README.md). Bootstrap vazio não tem custo fixo, orçamento de alertas é gratuito, e a base sem ECS e ALB está estimada em US$ 17 a 22/mês. O demo completo do desenho está estimado em US$ 105 a 115/mês, antes de tokens e tráfego. Essa estimativa soma cerca de US$ 18,25/mês de cinco IPv4 públicos à referência do desenho. Os US$ 200 durariam aproximadamente 53 a 58 dias com todo o demo ligado, conforme essa hipótese. [Preço de IPv4](https://aws.amazon.com/vpc/pricing/).

Após remover a base, persistem o orçamento gratuito, o usuário IAM, os buckets de state e segurança, versões de objetos e snapshots manuais. Estimativa de armazenamento: S3 Standard cerca de US$ 0,023/GB-mês e backup RDS cerca de US$ 0,095/GB-mês; um snapshot de referência de 20 GB custa aproximadamente US$ 1,90/mês. Nenhuma política de retenção apaga automaticamente o dado preservado.

## Desvios e pendências

- A renomeação direta da pasta do espelho recebeu acesso negado. O espelho foi recriado na pasta nova a partir da cópia local, com hash idêntico, e a pasta antiga foi removida após conferir que estava limpa.
- O orçamento permanece no state quando `destruir.ps1` remove a base com `habilitar_base=false`; isso conserva os alertas gratuitos entre ciclos. O script aplica um plano de remoção salvo, em vez de destruir o state inteiro.
- Papéis OIDC de web, contracts e infra foram criados no código sem políticas de acesso, pois esses espelhos não publicam imagem nesta entrega. Somente os cinco produtores recebem publicação ECR.
- A borda foi verificada com planos simulados. Imagens, domínio e certificado não foram inventados para um plano de aplicação.
- Faltam planos autenticados salvos, aprovações de cada apply e uma prova real de subir, preservar, destruir e restaurar. Nenhum desses passos foi considerado concluído.
- O usuário precisa configurar `prdal-terraform` no próprio terminal; a checagem realizada retornou perfil não encontrado. Desativar a chave do root continua reservado ao autor após validar o perfil novo.
- Faltam e-mail do orçamento, confirmação do limite de US$ 100 e decisão sobre domínio. Mesmo com CloudFront padrão no navegador, a origem HTTPS do ALB exige nome e certificado válidos.
- Bootstrap inicia com state local e migra ao bucket recém-criado conforme o README. Nenhuma migração de state ocorreu antes do apply aprovado.
- A retenção de snapshots e cópias antigos permanece com o autor; os custos crescem com dados e gerações preservadas.

O próximo passo é conferir o perfil novo, preparar e salvar o plano real do bootstrap, apresentar seu resumo e custo, e aguardar o ok específico antes do primeiro apply. Depois seguem orçamento e base, nessa ordem e com novas aprovações.
