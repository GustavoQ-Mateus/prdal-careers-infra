# Infraestrutura AWS

`bootstrap/` cria os buckets persistentes de state e cópia de segurança. `envs/demo/` contém o ambiente efêmero. `modules/` contém as unidades de rede, dados, fila, segredos, imagens, cluster, OIDC e borda. O perfil `prod` será definido após a validação do `demo`; ele usará tarefas em subnets privadas, NAT e maior retenção de backup.

Região: `us-east-1`. Conta: `765656213653`. Perfil CLI e Terraform: `prdal-terraform`. Todo comando Terraform deve definir `AWS_PROFILE=prdal-terraform` explicitamente.

Ordem de operação: bootstrap, orçamento e base do `demo`. Cada `apply` exige `fmt -check`, `validate`, plano salvo, apresentação do resumo e custo ao autor e aprovação específica. Os scripts em `envs/demo/` fazem snapshot e cópia dos dados antes de destruir e restauram na próxima subida.
