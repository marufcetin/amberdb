# bin/setup_ramdisk.ps1 - PowerShell ImDisk RAM-Disk Helper for AmberDB
# Run in an elevated PowerShell prompt (Run as Administrator)

param(
    [switch]$Stop,
    [string]$Drive = "R:",
    [string]$Size = "512M"
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "[ERROR] Administrator privileges required! Please run PowerShell as Administrator."
    return
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$cacheDir = Join-Path $projectDir "dbstore\cache"
$lockDir  = Join-Path $projectDir "dbstore\lock"

if ($Stop) {
    Write-Host "[RAM-DISK] Stopping ImDisk RAM-Disk on $Drive..." -ForegroundColor Yellow

    if (Test-Path $cacheDir) {
        cmd /c "rmdir /s /q `"$cacheDir`"" 2>$null
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $cacheDir "tables") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $cacheDir "conf") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $cacheDir "schema") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $cacheDir "lock") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $cacheDir "pids") -Force | Out-Null
    }

    if (Test-Path $lockDir) {
        cmd /c "rmdir /s /q `"$lockDir`"" 2>$null
    }

    & imdisk -D -m $Drive 2>$null
    Write-Host "[SUCCESS] RAM-Disk unmounted." -ForegroundColor Green
    return
}

Write-Host "[RAM-DISK] Starting ImDisk RAM-Disk on $Drive ($Size)..." -ForegroundColor Cyan

$imdiskCmd = Get-Command imdisk -ErrorAction SilentlyContinue
if (-not $imdiskCmd) {
    Write-Error "[ERROR] 'imdisk' CLI tool was not found on your system!"
    return
}

$driveRoot = "$Drive\"
if (-not (Test-Path $driveRoot)) {
    & imdisk -a -s $Size -m $Drive -p "/fs:ntfs /q /y"
}

New-Item -ItemType Directory -Path (Join-Path $driveRoot "tables") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $driveRoot "conf") -Force   | Out-Null
New-Item -ItemType Directory -Path (Join-Path $driveRoot "schema") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $driveRoot "lock") -Force   | Out-Null
New-Item -ItemType Directory -Path (Join-Path $driveRoot "pids") -Force   | Out-Null

if (Test-Path $lockDir) {
    cmd /c "rmdir /s /q `"$lockDir`"" 2>$null
}

if (Test-Path $cacheDir) {
    cmd /c "rmdir /s /q `"$cacheDir`"" 2>$null
}
cmd /c "mklink /J `"$cacheDir`" `"$driveRoot`"" | Out-Null

Write-Host "[SUCCESS] Windows ImDisk RAM-Disk is ready and linked to AmberDB!" -ForegroundColor Green
Write-Host "  Cache Root: $cacheDir -> $driveRoot"
Write-Host "  ├── tables/  (DB & Index cache)"
Write-Host "  ├── conf/    (Compiled config cache)"
Write-Host "  ├── schema/  (Table & DBase schema cache)"
Write-Host "  ├── lock/    (Flock lock files)"
Write-Host "  └── pids/    (Process & mutex files)"
