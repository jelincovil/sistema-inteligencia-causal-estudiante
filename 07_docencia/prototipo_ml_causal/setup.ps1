$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

function Find-Uv {
    $command = Get-Command uv -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }
    $candidates = @(
        (Join-Path $env:USERPROFILE ".local\bin\uv.exe"),
        (Join-Path $env:USERPROFILE ".cargo\bin\uv.exe")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }
    return $null
}

$uv = Find-Uv
if ($null -eq $uv) {
    # uv fijado por versión y SHA-256 (release 0.13.8 de astral-sh/uv).
    $uvVersion = "0.13.8"
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -eq "ARM64") {
        $uvFile = "uv-aarch64-pc-windows-msvc.zip"
        $uvSha = "59e6d919bed1f72035e622a7c930058f08a8931c4c78ceaf9f56e7fb74dd2c48"
    } else {
        $uvFile = "uv-x86_64-pc-windows-msvc.zip"
        $uvSha = "529e78a9cec6cd7e3e014f7ecd8bda0c113969d4ed0f2efeedb85c30943325b8"
    }
    $uvUrl = "https://github.com/astral-sh/uv/releases/download/$uvVersion/$uvFile"
    Write-Host "Instalando uv $uvVersion ($uvFile)..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $tmp = Join-Path $env:TEMP ("uv-setup-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        $zip = Join-Path $tmp $uvFile
        Invoke-WebRequest -Uri $uvUrl -OutFile $zip -UseBasicParsing
        $actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
        if ($actual -ne $uvSha) {
            throw "SHA-256 de $uvFile no coincide (esperado $uvSha, obtenido $actual). No se instaló nada."
        }
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        $uvExe = Get-ChildItem -Path $tmp -Recurse -Filter "uv.exe" |
                 Select-Object -First 1 -ExpandProperty FullName
        if ($null -eq $uvExe) {
            throw "El archivo descargado no contiene uv.exe."
        }
        $dest = Join-Path $env:USERPROFILE ".local\bin"
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Copy-Item -LiteralPath $uvExe -Destination (Join-Path $dest "uv.exe") -Force
        $env:Path = "$dest;$env:USERPROFILE\.cargo\bin;$env:Path"
        $uv = Find-Uv
    } finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}
if ($null -eq $uv) {
    throw "uv quedó instalado fuera de PATH. Abre otra terminal y repite el comando."
}

& $uv python install 3.13
if ($LASTEXITCODE -ne 0) { throw "No se pudo instalar Python 3.13 con uv." }

# Sin --clear: una venv existente se archiva en respaldo/ antes de crear la
# nueva (mismo patrón que el lanzador Windows). Nada se borra.
$venvPath = Join-Path $PSScriptRoot ".venv"
if (Test-Path -LiteralPath $venvPath) {
    $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
    New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot "respaldo") -Force | Out-Null
    Move-Item -LiteralPath $venvPath -Destination (Join-Path $PSScriptRoot "respaldo\venv-$stamp")
    Write-Host ".venv existente archivada en respaldo\venv-$stamp"
}
& $uv venv --python 3.13 .venv
if ($LASTEXITCODE -ne 0) { throw "No se pudo crear .venv." }

$python = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
$requirements = Join-Path $PSScriptRoot "requirements.txt"
& $uv pip install --python $python -r $requirements
if ($LASTEXITCODE -ne 0) { throw "No se pudieron instalar las dependencias." }

& $uv pip check --python $python
if ($LASTEXITCODE -ne 0) { throw "Las dependencias instaladas no son coherentes." }
& $python --version
if ($LASTEXITCODE -ne 0) { throw "El intérprete de .venv no responde." }

Write-Host ""
Write-Host "Instalación lista. Ejecuta: powershell -ExecutionPolicy Bypass -File arrancar.ps1"
Write-Host "URL: http://127.0.0.1:8000"
Write-Host "Endpoints: http://127.0.0.1:8000/efecto"
Write-Host "           http://127.0.0.1:8000/salud"
Write-Host "           http://127.0.0.1:8000/docs"
