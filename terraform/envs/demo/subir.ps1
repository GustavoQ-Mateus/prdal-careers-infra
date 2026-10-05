param(
    [Parameter(Mandatory = $true)][ValidateSet('demo')][string]$Ambiente,
    [Parameter(Mandatory = $true)][string]$EmailOrcamento,
    [decimal]$LimiteMensal = 100,
    [switch]$Executar
)

$ErrorActionPreference = 'Stop'
$env:AWS_PROFILE = 'prdal-terraform'
$env:AWS_DEFAULT_REGION = 'us-east-1'
$identidade = aws sts get-caller-identity --profile prdal-terraform --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $identidade.Account -ne '765656213653' -or $identidade.Arn -ne 'arn:aws:iam::765656213653:user/prdal-terraform') {
    throw 'Identidade AWS diferente da autorizada'
}
$diretorio = Split-Path -Parent $MyInvocation.MyCommand.Path
$plano = Join-Path $diretorio 'subir.tfplan'
$arquivo = [System.IO.Path]::GetTempFileName()

Push-Location $diretorio
try {
    terraform init -input=false
    if ($LASTEXITCODE -ne 0) { throw 'Falha no init' }
    terraform fmt -check -recursive
    if ($LASTEXITCODE -ne 0) { throw 'Falha no fmt' }
    terraform validate
    if ($LASTEXITCODE -ne 0) { throw 'Falha no validate' }
    terraform state show 'module.orcamento.aws_budgets_budget.mensal' *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Aplique somente o orçamento antes de subir a base' }
    $recursos = @(terraform state list)
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao consultar o state' }
    $bancoExistente = $recursos -contains 'module.rds[0].aws_db_instance.postgres'
    $artefatosExistentes = $recursos -contains 'module.artefatos[0].aws_s3_bucket.artefatos'
    $manifesto = $null
    $quantidade = aws s3api list-objects-v2 --bucket prdal-careers-seguranca-765656213653 --prefix demo/restauracao.json --query KeyCount --output text --profile prdal-terraform --region us-east-1
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao consultar a cópia de segurança' }
    if ([int]$quantidade -gt 0) {
        aws s3 cp 's3://prdal-careers-seguranca-765656213653/demo/restauracao.json' $arquivo --profile prdal-terraform --region us-east-1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao ler o manifesto de restauração' }
        $manifesto = Get-Content -Raw -LiteralPath $arquivo | ConvertFrom-Json
    }
    $argumentos = @('-input=false', '-out', $plano, '-var', "email_orcamento=$EmailOrcamento", '-var', "limite_mensal=$LimiteMensal", '-var', 'habilitar_base=true')
    if ($manifesto -and -not $bancoExistente) {
        aws rds describe-db-snapshots --db-snapshot-identifier $manifesto.snapshot --profile prdal-terraform --region us-east-1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Snapshot de restauração indisponível' }
        $argumentos += @('-var', "snapshot_identifier=$($manifesto.snapshot)")
    }
    terraform plan @argumentos
    if ($LASTEXITCODE -ne 0) { throw 'Falha no plan' }
    terraform show -no-color $plano
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao mostrar o plano' }
    Write-Output 'Estimativa da base: US$ 17 a 22/mês, mais armazenamento e tráfego por uso. ECS e ALB ainda não são aplicados. Confira a estimativa atual do README antes de autorizar.'
    if (-not $Executar) { return }
    if ((Read-Host 'Digite APLICAR para autorizar este único apply') -cne 'APLICAR') { throw 'Apply cancelado' }
    terraform apply -input=false $plano
    if ($LASTEXITCODE -ne 0) { throw 'Falha no apply' }
    if ($manifesto -and -not $artefatosExistentes) {
        aws s3 sync "s3://prdal-careers-seguranca-765656213653/$($manifesto.prefixo)" 's3://prdal-careers-demo-artefatos-765656213653/' --profile prdal-terraform --region us-east-1
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao restaurar os artefatos' }
    }
} finally {
    Pop-Location
    Remove-Item -LiteralPath $arquivo -Force
}
