$ErrorActionPreference = 'Stop'
$subir = Join-Path (Split-Path -Parent $PSScriptRoot) 'subir.ps1'
$destruir = Join-Path (Split-Path -Parent $PSScriptRoot) 'destruir.ps1'
$global:testeeventos = [System.Collections.Generic.List[string]]::new()
$global:testetemBanco = $false
$global:testetemManifesto = $false
$global:testefalharSnapshot = $false
$global:testeaplicado = $false
$global:testeconfirmacao = 'APLICAR'
$global:testeultimoPlano = @()

function aws {
    $argumentos = @($args)
    $global:LASTEXITCODE = 0
    $operacao = $argumentos[0..1] -join ' '
    $global:testeeventos.Add($operacao)
    switch ($operacao) {
        'sts get-caller-identity' { '{"Account":"765656213653","Arn":"arn:aws:iam::765656213653:user/prdal-terraform"}' }
        's3api list-objects-v2' { if ($global:testetemManifesto) { '1' } else { '0' } }
        's3 cp' {
            if ($argumentos[2] -eq 's3://prdal-careers-seguranca-765656213653/demo/restauracao.json') {
                '{"snapshot":"prdal-demo-teste","prefixo":"artefatos/prdal-demo-teste/"}' | Set-Content -LiteralPath $argumentos[3] -Encoding UTF8
            }
        }
        's3 sync' {}
        'rds describe-db-snapshots' {}
        'rds create-db-snapshot' { if ($global:testefalharSnapshot) { $global:LASTEXITCODE = 1 } }
        'rds wait' {}
        default { throw "Comando AWS não simulado: $operacao" }
    }
}

function terraform {
    $argumentos = @($args)
    $global:LASTEXITCODE = 0
    $global:testeeventos.Add('terraform ' + $argumentos[0])
    switch ($argumentos[0]) {
        'init' {}
        'fmt' {}
        'validate' {}
        'show' {}
        'plan' { $global:testeultimoPlano = $argumentos }
        'apply' { $global:testeaplicado = $true }
        'state' {
            if ($argumentos[1] -eq 'list') {
                'module.orcamento.aws_budgets_budget.mensal'
                if ($global:testetemBanco -and -not $global:testeaplicado) {
                    'module.rds[0].aws_db_instance.postgres'
                    'module.artefatos[0].aws_s3_bucket.artefatos'
                }
            }
        }
        default { throw "Comando Terraform não simulado: $($argumentos[0])" }
    }
}

function Read-Host { $global:testeconfirmacao }

function Exigir {
    param([bool]$Condicao, [string]$Mensagem)
    if (-not $Condicao) { throw $Mensagem }
}

function Reiniciar {
    $global:testeeventos.Clear()
    $global:testetemBanco = $false
    $global:testetemManifesto = $false
    $global:testefalharSnapshot = $false
    $global:testeaplicado = $false
}

Reiniciar
& $subir -Ambiente demo -EmailOrcamento 'orcamento@example.invalid' | Out-Null
Exigir (-not $global:testeaplicado) 'Subir executou apply sem Executar'
Exigir (-not $global:testeeventos.Contains('s3 sync')) 'Subir copiou dados durante simulação'

Reiniciar
& $destruir -Ambiente demo -EmailOrcamento 'orcamento@example.invalid' | Out-Null
Exigir (-not $global:testeaplicado) 'Destruir executou apply sem Executar'
Exigir (-not $global:testeeventos.Contains('rds create-db-snapshot')) 'Destruir criou snapshot durante simulação'

Reiniciar
$global:testetemBanco = $true
$global:testefalharSnapshot = $true
$global:testeconfirmacao = 'DESTRUIR'
$falhou = $false
try { & $destruir -Ambiente demo -EmailOrcamento 'orcamento@example.invalid' -Executar | Out-Null } catch { $falhou = $true }
Exigir ($falhou -and -not $global:testeaplicado) 'Falha no snapshot não impediu destruição'

Reiniciar
$global:testetemBanco = $true
& $destruir -Ambiente demo -EmailOrcamento 'orcamento@example.invalid' -Executar | Out-Null
Exigir ($global:testeaplicado) 'Destruição aprovada não foi executada'
Exigir ($global:testeeventos.IndexOf('rds create-db-snapshot') -lt $global:testeeventos.IndexOf('rds wait')) 'Snapshot não foi aguardado'
Exigir ($global:testeeventos.IndexOf('s3 sync') -lt $global:testeeventos.IndexOf('terraform apply')) 'Destruição ocorreu antes da cópia'
Exigir ($global:testeeventos.IndexOf('s3 cp') -lt $global:testeeventos.IndexOf('terraform apply')) 'Destruição ocorreu antes do manifesto'

Reiniciar
$global:testetemBanco = $true
$global:testetemManifesto = $true
$global:testeconfirmacao = 'APLICAR'
& $subir -Ambiente demo -EmailOrcamento 'orcamento@example.invalid' -Executar | Out-Null
Exigir (-not $global:testeeventos.Contains('s3 sync')) 'Subida repetida sobrescreveu artefatos ativos'
Exigir (-not ($global:testeultimoPlano -contains 'snapshot_identifier=prdal-demo-teste')) 'Subida repetida tentou restaurar banco ativo'

Reiniciar
$global:testetemManifesto = $true
& $subir -Ambiente demo -EmailOrcamento 'orcamento@example.invalid' -Executar | Out-Null
Exigir ($global:testeultimoPlano -contains 'snapshot_identifier=prdal-demo-teste') 'Snapshot não foi selecionado para restauração'
Exigir ($global:testeeventos.IndexOf('s3 sync') -gt $global:testeeventos.IndexOf('terraform apply')) 'Artefatos não foram restaurados após apply'
Write-Output '6 cenários passaram; nenhuma chamada real à AWS ou ao Terraform'
