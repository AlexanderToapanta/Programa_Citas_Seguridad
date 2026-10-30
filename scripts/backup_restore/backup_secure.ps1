param (
    [string]$BackupDir = ".\backups_offline"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$DumpFileName = "iess_turnos_db_$Timestamp.dump"
$DumpFilePath = Join-Path $BackupDir $DumpFileName
$ZipFilePath = "$DumpFilePath.zip"
$ChecksumFilePath = "$DumpFilePath.sha256"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [R12 CONTRAMEDIDA] GENERACIÓN DE RESPALDO SEGURO POSTGRESQL " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

Write-Host "[1/4] Extrayendo volcado consistente binario (pg_dump -F c)..." -ForegroundColor Yellow
# Ejecutar pg_dump dentro del contenedor postgres de forma consistente
cmd.exe /c "docker compose exec -T postgres pg_dump -U iess_user -d iess_turnos_db -F c -b" > $DumpFilePath

if ((Get-Item $DumpFilePath).Length -lt 1000) {
    Write-Error "El archivo generado parece estar corrupto o vacío."
    exit 1
}

Write-Host "[2/4] Comprimiendo y protegiendo el artefacto de respaldo..." -ForegroundColor Yellow
Compress-Archive -Path $DumpFilePath -DestinationPath $ZipFilePath -Force
Remove-Item -Path $DumpFilePath -Force

Write-Host "[3/4] Generando suma de verificación criptográfica (SHA-256)..." -ForegroundColor Yellow
$Hash = (Get-FileHash -Path $ZipFilePath -Algorithm SHA256).Hash
"$Hash  $((Get-Item $ZipFilePath).Name)" | Out-File -FilePath $ChecksumFilePath -Encoding utf8

Write-Host "[4/4] Estableciendo atributos de solo lectura (simulación WORM/inmutable)..." -ForegroundColor Yellow
Set-ItemProperty -Path $ZipFilePath -Name IsReadOnly -Value $true
Set-ItemProperty -Path $ChecksumFilePath -Name IsReadOnly -Value $true

Write-Host ""
Write-Host "✓ RESPALDO COMPLETADO EXITOSAMENTE" -ForegroundColor Green
Write-Host "  Archivo inmutable : $ZipFilePath" -ForegroundColor Gray
Write-Host "  Checksum SHA-256  : $Hash" -ForegroundColor Gray
Write-Host "  Tamaño            : $((Get-Item $ZipFilePath).Length) bytes" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Cyan

