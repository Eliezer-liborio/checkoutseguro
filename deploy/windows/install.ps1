# =============================================================================
#  CheckoutSeguro — Instalador para Windows
#  Requer: PowerShell 5.1+ e Python 3.9+
#  Uso (como Administrador):
#    Set-ExecutionPolicy Bypass -Scope Process -Force
#    .\deploy\windows\install.ps1
# =============================================================================

#Requires -Version 5.1

param(
    [int]$Port = 7432,
    [switch]$NoService,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# ── Cores e helpers ──────────────────────────────────────────────────────────
function Write-Step   { param($msg) Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Write-Ok     { param($msg) Write-Host "  [OK]   $msg" -ForegroundColor Green }
function Write-Info   { param($msg) Write-Host "  [INFO] $msg" -ForegroundColor Gray }
function Write-Warn   { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Fail   { param($msg) Write-Host "  [ERRO] $msg" -ForegroundColor Red; exit 1 }

# ── Banner ───────────────────────────────────────────────────────────────────
Write-Host @"
  _____ _               _               _   ____
 / ____| |             | |             | | / ___|  ___  __ _ _   _ _ __ ___
| |    | |__   ___  ___| | _____  _   _| || (___  / _ \/ _` | | | | '__/ _ \
| |    | '_ \ / _ \/ __| |/ / _ \| | | | |\___  \|  __/ (_| | |_| | | | (_) |
| |____| | | |  __/ (__|   < (_) | |_| | |____) | \___|\__, |\__,_|_|  \___/
 \_____|_| |_|\___|\___|_|\_\___/ \__,_|_|_____/          |_|
                  Instalador para Windows
"@ -ForegroundColor Green

# ── Variáveis ────────────────────────────────────────────────────────────────
$InstallDir  = "$env:USERPROFILE\.checkoutseguro"
$AppDir      = "$InstallDir\app"
$VenvDir     = "$InstallDir\venv"
$CertsDir    = "$InstallDir\certs"
$WalletDir   = "$InstallDir\wallet"
$LogDir      = "$InstallDir\logs"
$EnvFile     = "$InstallDir\.env"
$RepoUrl     = "https://github.com/Eliezer-liborio/checkoutseguro"
$ServiceName = "CheckoutSeguro"

# ── Verificação de dependências ──────────────────────────────────────────────
Write-Step "Verificando dependências"

# Python
try {
    $pyVersion = (python --version 2>&1).ToString()
    if ($pyVersion -match "Python (\d+)\.(\d+)") {
        $major = [int]$Matches[1]; $minor = [int]$Matches[2]
        if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 9)) {
            Write-Fail "Python 3.9+ necessário. Versão atual: $pyVersion"
        }
        Write-Ok "Python $pyVersion encontrado"
        $PythonCmd = "python"
    }
} catch {
    Write-Fail "Python não encontrado. Instale em https://python.org/downloads"
}

# pip
try {
    python -m pip --version | Out-Null
    Write-Ok "pip disponível"
} catch {
    Write-Fail "pip não encontrado. Execute: python -m ensurepip --upgrade"
}

# openssl (para certificado HTTPS)
$HasOpenSSL = $false
try {
    openssl version | Out-Null
    Write-Ok "openssl disponível"
    $HasOpenSSL = $true
} catch {
    Write-Warn "openssl não encontrado. HTTPS local desabilitado."
}

# ── Criação de diretórios ────────────────────────────────────────────────────
Write-Step "Criando estrutura de diretórios"
@($AppDir, $VenvDir, $CertsDir, $WalletDir, $LogDir) | ForEach-Object {
    New-Item -ItemType Directory -Force -Path $_ | Out-Null
}
Write-Ok "Diretórios criados em $InstallDir"

# ── Cópia dos arquivos ───────────────────────────────────────────────────────
Write-Step "Instalando arquivos da aplicação"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent (Split-Path -Parent $ScriptDir)

if (Test-Path "$RepoRoot\app\main.py") {
    Copy-Item -Path "$RepoRoot\app\*" -Destination $AppDir -Recurse -Force
    Write-Ok "Arquivos copiados de $RepoRoot\app\"
} else {
    Write-Fail "Arquivos da aplicação não encontrados. Clone o repositório primeiro."
}

# ── Ambiente virtual Python ──────────────────────────────────────────────────
Write-Step "Criando ambiente virtual Python"
python -m venv $VenvDir
& "$VenvDir\Scripts\pip" install --upgrade pip --quiet
Write-Ok "Ambiente virtual criado"

Write-Step "Instalando dependências Python"
& "$VenvDir\Scripts\pip" install --quiet `
    "fastapi>=0.110.0" `
    "uvicorn[standard]>=0.29.0" `
    "eth-account>=0.11.0" `
    "bcrypt>=4.1.0" `
    "cryptography>=42.0.0" `
    "python-multipart>=0.0.9"
Write-Ok "Dependências instaladas"

# ── Certificado HTTPS local ──────────────────────────────────────────────────
$UseHttps = $false
if ($HasOpenSSL) {
    Write-Step "Gerando certificado TLS autoassinado"
    $CertFile = "$CertsDir\cert.pem"
    $KeyFile  = "$CertsDir\key.pem"
    if (-not (Test-Path $CertFile)) {
        openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes `
            -keyout $KeyFile -out $CertFile `
            -subj "/CN=localhost" `
            -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>$null
        Write-Ok "Certificado gerado: $CertFile"
    } else {
        Write-Info "Certificado já existe, pulando geração"
    }
    $UseHttps = $true
}

# ── Arquivo .env ─────────────────────────────────────────────────────────────
Write-Step "Criando arquivo de configuração"
if (-not (Test-Path $EnvFile)) {
    @"
# CheckoutSeguro — Configuração de Produção
# Gerado em $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

CHECKOUTSEGURO_PORT=$Port
CHECKOUTSEGURO_DB_PATH=$WalletDir\identity.db
CHECKOUTSEGURO_USE_HTTPS=$($UseHttps.ToString().ToLower())
CHECKOUTSEGURO_CERT_FILE=$CertsDir\cert.pem
CHECKOUTSEGURO_KEY_FILE=$CertsDir\key.pem
CHECKOUTSEGURO_ENV=production
CHECKOUTSEGURO_LOG_LEVEL=info
"@ | Set-Content -Path $EnvFile -Encoding UTF8
    Write-Ok "Arquivo .env criado"
}

# ── Script de inicialização .bat ─────────────────────────────────────────────
Write-Step "Criando scripts de controle"
$StartBat = "$InstallDir\start.bat"
@"
@echo off
REM CheckoutSeguro — Inicialização
call "$VenvDir\Scripts\activate.bat"
cd /d "$AppDir"
uvicorn main:app --host 127.0.0.1 --port $Port --log-level info --no-access-log
"@ | Set-Content -Path $StartBat -Encoding ASCII

$StopBat = "$InstallDir\stop.bat"
@"
@echo off
REM CheckoutSeguro — Parada
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":$Port"') do (
    taskkill /PID %%a /F >nul 2>&1
    echo CheckoutSeguro parado (PID %%a)
)
"@ | Set-Content -Path $StopBat -Encoding ASCII
Write-Ok "Scripts criados: start.bat / stop.bat"

# ── Instalação como serviço Windows (Task Scheduler) ────────────────────────
if (-not $NoService) {
    Write-Step "Registrando tarefa no Agendador de Tarefas do Windows"
    try {
        $Action  = New-ScheduledTaskAction -Execute $StartBat
        $Trigger = New-ScheduledTaskTrigger -AtLogOn
        $Settings = New-ScheduledTaskSettingsSet `
            -ExecutionTimeLimit (New-TimeSpan -Hours 0) `
            -RestartCount 3 `
            -RestartInterval (New-TimeSpan -Minutes 1) `
            -StartWhenAvailable

        Register-ScheduledTask `
            -TaskName $ServiceName `
            -Action $Action `
            -Trigger $Trigger `
            -Settings $Settings `
            -RunLevel Limited `
            -Force | Out-Null

        Write-Ok "Tarefa '$ServiceName' registrada (inicia automaticamente no login)"
        Write-Info "Para gerenciar: Abra 'Agendador de Tarefas' e procure por '$ServiceName'"
    } catch {
        Write-Warn "Não foi possível registrar a tarefa: $_"
        Write-Info "Inicie manualmente: $StartBat"
    }
}

# ── Verificação pós-instalação ───────────────────────────────────────────────
Write-Step "Verificando instalação"
Start-Process -FilePath $StartBat -WindowStyle Hidden
Start-Sleep -Seconds 4

$Proto = if ($UseHttps) { "https" } else { "http" }
try {
    $response = Invoke-WebRequest -Uri "${Proto}://127.0.0.1:${Port}/status" `
        -UseBasicParsing -SkipCertificateCheck -TimeoutSec 5
    if ($response.Content -match '"running":true') {
        Write-Ok "CheckoutSeguro rodando em ${Proto}://localhost:${Port}"
    }
} catch {
    Write-Warn "Não foi possível verificar. Inicie manualmente: $StartBat"
}

# ── Resumo ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅  CheckoutSeguro instalado com sucesso!" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  Interface:    ${Proto}://localhost:${Port}" -ForegroundColor Cyan
Write-Host "  Dados:        $WalletDir\" -ForegroundColor Cyan
Write-Host "  Logs:         $LogDir\" -ForegroundColor Cyan
Write-Host "  Configuração: $EnvFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Próximos passos:" -ForegroundColor Yellow
Write-Host "  1. Acesse ${Proto}://localhost:${Port} para criar sua identidade"
Write-Host "  2. Instale a extensão do navegador (pasta extension\)"
Write-Host "  3. Faça backup da sua Frase de Segurança em local seguro"
Write-Host ""
