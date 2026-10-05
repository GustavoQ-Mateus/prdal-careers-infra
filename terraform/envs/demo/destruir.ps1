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
$plano = Join-Path $diretorio 'destruir.tfplan'
$arquivo = [System.IO.Path]::GetTempFileName()

Push-Location $diretorio
try {
    terraform init -input=false
    if ($LASTEXITCODE -ne 0) { throw 'Falha no init' }
    terraform fmt -check -recursive
    if ($LASTEXITCODE -ne 0) { throw 'Falha no fmt' }
    terraform validate
    if ($LASTEXITCODE -ne 0) { throw 'Falha no validate' }
    terraform plan -input=false -out $plano -var "email_orcamento=$EmailOrcamento" -var "limite_mensal=$LimiteMensal" -var 'habilitar_base=false'
    if ($LASTEXITCODE -ne 0) { throw 'Falha no plan de destruição' }
    terraform show -no-color $plano
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao mostrar o plano' }
    Write-Output 'Custo residual: S3 a cerca de US$ 0,023/GB-mês e snapshots RDS a cerca de US$ 0,095/GB-mês. Permanecem o orçamento sem custo fixo e os buckets persistentes. Snapshots e cópias antigas acumulam armazenamento.'
    if (-not $Executar) { return }
    if ((Read-Host 'Digite DESTRUIR para autorizar esta única destruição') -cne 'DESTRUIR') { throw 'Destruição cancelada' }
    $recursos = @(terraform state list)
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao consultar o state' }
    $bancoExistente = $recursos -contains 'module.rds[0].aws_db_instance.postgres'
    $artefatosExistentes = $recursos -contains 'module.artefatos[0].aws_s3_bucket.artefatos'
    if ($bancoExistente -xor $artefatosExistentes) { throw 'State parcial de dados; preserve a cópia antes de continuar' }
    if ($bancoExistente) {
        $identificador = 'prdal-demo-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
        aws rds create-db-snapshot --db-instance-identifier prdal-demo-postgres --db-snapshot-identifier $identificador --tags Key=projeto,Value=prdal-careers Key=ambiente,Value=demo Key=dono,Value=gusta --profile prdal-terraform --region us-east-1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar snapshot' }
        aws rds wait db-snapshot-available --db-snapshot-identifier $identificador --profile prdal-terraform --region us-east-1
        if ($LASTEXITCODE -ne 0) { throw 'Snapshot não ficou disponível' }
        $prefixo = "artefatos/$identificador/"
        aws s3 sync 's3://prdal-careers-demo-artefatos-765656213653/' "s3://prdal-careers-seguranca-765656213653/$prefixo" --profile prdal-terraform --region us-east-1
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao copiar artefatos' }
        @{ snapshot = $identificador; prefixo = $prefixo } | ConvertTo-Json | Set-Content -LiteralPath $arquivo -Encoding UTF8
        aws s3 cp $arquivo 's3://prdal-careers-seguranca-765656213653/demo/restauracao.json' --profile prdal-terraform --region us-east-1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao gravar o manifesto da cópia' }
    }
    terraform apply -input=false $plano
    if ($LASTEXITCODE -ne 0) { throw 'Falha na destruição' }
    $restantes = @(terraform state list | Where-Object { $_ -notmatch '^module\.orcamento\.' })
    if ($restantes.Count -gt 0) { throw 'Há recursos do demo ainda no state; revise a destruição' }
} finally {
    Pop-Location
    Remove-Item -LiteralPath $arquivo -Force
}
