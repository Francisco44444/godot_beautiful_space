param(
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"
$launcherVersion = "1.0.0"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$channelPath = Join-Path $root "channel.json"
$gamePath = Join-Path $root "game"
$backup = Join-Path $root "game.previous"
$versionPath = Join-Path $gamePath "version.txt"
$fallbackExe = Join-Path $gamePath "SenderosDelHorizonte.exe"
$singleInstance = New-Object System.Threading.Mutex($false, "Local\SenderosDelHorizonteUpdater")
$lockAcquired = $false
try {
    $lockAcquired = $singleInstance.WaitOne(0)
} catch [System.Threading.AbandonedMutexException] {
    $lockAcquired = $true
}
if (-not $lockAcquired) {
    Write-Host "El actualizador ya esta abierto; se usara esa instancia."
    exit 0
}

function Start-InstalledGame {
    param([string]$Executable)
    if (-not (Test-Path $Executable)) {
        throw "No hay una version instalada y no se pudo descargar la actualizacion."
    }
    if (-not $NoLaunch) {
        Start-Process -FilePath $Executable -WorkingDirectory (Split-Path -Parent $Executable)
    }
}

function Read-InstalledVersion {
    if (Test-Path $versionPath) {
        return (Get-Content $versionPath -Raw).Trim()
    }
    return "0.0.0"
}

function Restore-InterruptedUpdate {
    if ((-not (Test-Path $gamePath)) -and (Test-Path $backup)) {
        Write-Warning "Se detecto una actualizacion interrumpida; restaurando la version anterior."
        Move-Item $backup $gamePath
    }
}

try {
try {
    Restore-InterruptedUpdate
    if (-not (Test-Path $channelPath)) {
        throw "Falta channel.json junto al lanzador."
    }
    $channel = Get-Content $channelPath -Raw | ConvertFrom-Json
    if (-not $channel.manifest_url -or $channel.manifest_url -like "*PENDING*") {
        throw "El canal de actualizaciones aun no ha sido publicado."
    }

    Write-Host "Buscando actualizaciones..."
    $manifest = Invoke-RestMethod -Uri $channel.manifest_url -TimeoutSec 20 -Headers @{ "Cache-Control" = "no-cache" }
    if ($manifest.schema -ne 1 -or -not $manifest.windows) {
        throw "El manifiesto remoto no tiene el formato esperado."
    }
    if ([version]$manifest.minimum_launcher_version -gt [version]$launcherVersion) {
        throw "Esta version del lanzador es demasiado antigua. Descarga el instalador nuevo."
    }

    $installedVersion = Read-InstalledVersion
    $remoteVersion = [string]$manifest.version
    $remoteExe = [string]$manifest.windows.executable
    $executable = Join-Path $gamePath $remoteExe
    $mustUpdate = ([version]$remoteVersion -gt [version]$installedVersion) -or (-not (Test-Path $executable))

    if ($mustUpdate) {
        Write-Host "Descargando Senderos del Horizonte $remoteVersion..."
        $download = Join-Path $env:TEMP "SenderosDelHorizonte-$remoteVersion.zip.partial"
        $staging = Join-Path $root "game.new"
        Remove-Item $download -Force -ErrorAction SilentlyContinue
        Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $staging -Force | Out-Null

        Invoke-WebRequest -Uri $manifest.windows.url -OutFile $download -TimeoutSec 1800 -UseBasicParsing
        $actualHash = (Get-FileHash $download -Algorithm SHA256).Hash.ToLowerInvariant()
        $expectedHash = ([string]$manifest.windows.sha256).ToLowerInvariant()
        if ($actualHash -ne $expectedHash) {
            throw "La descarga no supera la verificacion SHA-256; se conserva la version instalada."
        }
        if ($manifest.windows.size_bytes -and (Get-Item $download).Length -ne [int64]$manifest.windows.size_bytes) {
            throw "El tamano descargado no coincide con el manifiesto; se conserva la version instalada."
        }

        Expand-Archive -Path $download -DestinationPath $staging -Force
        $stagedExe = Join-Path $staging $remoteExe
        if (-not (Test-Path $stagedExe)) {
            throw "El paquete verificado no contiene $remoteExe."
        }
        Set-Content -Path (Join-Path $staging "version.txt") -Value $remoteVersion -Encoding ASCII

        Remove-Item $backup -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $gamePath) {
            Move-Item $gamePath $backup
        }
        try {
            Move-Item $staging $gamePath
        } catch {
            if (Test-Path $backup) {
                Remove-Item $gamePath -Recurse -Force -ErrorAction SilentlyContinue
                Move-Item $backup $gamePath
            }
            throw
        }
        Remove-Item $backup -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $download -Force -ErrorAction SilentlyContinue
        $executable = Join-Path $gamePath $remoteExe
        Write-Host "Actualizacion $remoteVersion instalada."
    } else {
        Write-Host "La version $installedVersion ya esta al dia."
    }

    Start-InstalledGame $executable
    exit 0
} catch {
    Write-Warning $_.Exception.Message
    Write-Host "Se intentara iniciar la ultima version valida instalada."
    try {
        Start-InstalledGame $fallbackExe
        exit 0
    } catch {
        Write-Error $_.Exception.Message
        exit 1
    }
}
} finally {
    if ($lockAcquired) {
        $singleInstance.ReleaseMutex()
    }
    $singleInstance.Dispose()
}
