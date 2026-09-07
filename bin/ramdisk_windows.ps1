# bin/ramdisk_windows.ps1 - Windows ImDisk RAM-Disk Helper for AmberDB
# Run with Administrator privileges (or via ramdisk_amberdb.pl)
# Usage:
#   powershell -ExecutionPolicy Bypass -File bin/ramdisk_windows.ps1 -Action start -Size 512M -ProjectName amberdb
#   powershell -ExecutionPolicy Bypass -File bin/ramdisk_windows.ps1 -Action stop -ProjectName amberdb
#   powershell -ExecutionPolicy Bypass -File bin/ramdisk_windows.ps1 -Action status -ProjectName amberdb

param(
    [ValidateSet("start", "mount", "stop", "unmount", "status")]
    [string]$Action = "status",
    [string]$Drive = "R:",
    [string]$Size = "512M",
    [string]$ProjectName = "",
    [string]$ProjectDir = ""
)

# 1. Resolve Project Paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ProjectDir) {
    $ProjectDir = Split-Path -Parent $scriptDir
}
$ProjectDir = (Resolve-Path $ProjectDir).Path

if (-not $ProjectName) {
    $ProjectName = Split-Path -Leaf $ProjectDir
}

$ramdiskDir   = Join-Path $ProjectDir "dbstore\ramdisk"
$lockDir      = Join-Path $ProjectDir "dbstore\lock"
$driveRoot    = "$Drive\"
$projectRam   = Join-Path $driveRoot $ProjectName

# Subfolders required by AmberDB
$subdirs = @("tables", "conf", "schema", "lock", "pids")

function Check-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "[ERROR] Administrator privileges required! Please right-click PowerShell and select 'Run as Administrator'."
        exit 1
    }
}

# --- Action: STATUS ---
if ($Action -eq "status") {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host " AmberDB Windows RAM-Disk Status Monitor" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "Platform:       Windows ($([Environment]::OSVersion.VersionString))"
    Write-Host "Project Name:   $ProjectName"
    Write-Host "Project Root:   $ProjectDir"
    Write-Host "Local RAM Path: $ramdiskDir"
    Write-Host "RAM Drive:      $Drive ($projectRam)"

    $driveExists = Test-Path $driveRoot
    $projectRamExists = Test-Path $projectRam

    if ($driveExists -and $projectRamExists) {
        Write-Host "RAM-Disk:       ACTIVE (Mounted on $projectRam)" -ForegroundColor Green
    }
    elseif ($driveExists) {
        Write-Host "RAM-Disk:       DRIVE ACTIVE ($Drive mounted, but project folder $ProjectName not initialized)" -ForegroundColor Yellow
    }
    else {
        Write-Host "RAM-Disk:       INACTIVE (Running on local storage)" -ForegroundColor Gray
    }
    Write-Host "=================================================================" -ForegroundColor Cyan
    return
}

# Require admin for start / stop
Check-Admin

# --- Action: STOP / UNMOUNT ---
if ($Action -eq "stop" -or $Action -eq "unmount") {
    Write-Host "[RAM-DISK] Stopping AmberDB RAM-Disk for project '$ProjectName'..." -ForegroundColor Yellow

    # Remove junction link
    if (Test-Path $ramdiskDir) {
        cmd /c "rmdir `"$ramdiskDir`"" 2>$null
        New-Item -ItemType Directory -Path $ramdiskDir -Force | Out-Null
        foreach ($sub in $subdirs) {
            New-Item -ItemType Directory -Path (Join-Path $ramdiskDir $sub) -Force | Out-Null
        }
    }

    if (Test-Path $lockDir) {
        cmd /c "rmdir /s /q `"$lockDir`"" 2>$null
    }

    # If project RAM folder exists, clean it
    if (Test-Path $projectRam) {
        cmd /c "rmdir /s /q `"$projectRam`"" 2>$null
    }

    # If drive R: has no remaining project folders, unmount it
    if (Test-Path $driveRoot) {
        $remaining = Get-ChildItem $driveRoot -Directory -ErrorAction SilentlyContinue
        if (-not $remaining -or $remaining.Count -eq 0) {
            Write-Host "[RAM-DISK] No other projects active. Unmounting drive $Drive..." -ForegroundColor Yellow
            & imdisk -D -m $Drive 2>$null
        }
    }

    Write-Host "[SUCCESS] RAM-Disk unmounted and restored to local storage for '$ProjectName'." -ForegroundColor Green
    return
}

# --- Action: START / MOUNT ---
if ($Action -eq "start" -or $Action -eq "mount") {
    Write-Host "[RAM-DISK] Initializing Windows ImDisk RAM-Disk for '$ProjectName' ($Size)..." -ForegroundColor Cyan

    $imdiskCmd = Get-Command imdisk -ErrorAction SilentlyContinue
    if (-not $imdiskCmd) {
        Write-Error "[ERROR] 'imdisk' CLI tool was not found on your system!`nInstall via Chocolatey: choco install ImDisk-Toolkit`nOr download: https://sourceforge.net/projects/imdisk-toolkit/"
        exit 1
    }

    # 1. Mount RAM drive if not mounted
    if (-not (Test-Path $driveRoot)) {
        Write-Host "[RAM-DISK] Mounting $Size RAM drive on $Drive..."
        & imdisk -a -s $Size -m $Drive -p "/fs:ntfs /q /y"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "[ERROR] Failed to mount ImDisk drive $Drive"
            exit 1
        }
    }

    # 2. Create isolated project folder on RAM drive
    if (-not (Test-Path $projectRam)) {
        New-Item -ItemType Directory -Path $projectRam -Force | Out-Null
    }
    foreach ($sub in $subdirs) {
        $subPath = Join-Path $projectRam $sub
        if (-not (Test-Path $subPath)) {
            New-Item -ItemType Directory -Path $subPath -Force | Out-Null
        }
    }

    # 3. Clean legacy lock dir
    if (Test-Path $lockDir) {
        cmd /c "rmdir /s /q `"$lockDir`"" 2>$null
    }

    # 4. Link dbstore\ramdisk to R:\<ProjectName>
    if (Test-Path $ramdiskDir) {
        cmd /c "rmdir /s /q `"$ramdiskDir`"" 2>$null
    }
    cmd /c "mklink /J `"$ramdiskDir`" `"$projectRam`"" 2>$null | Out-Null

    Write-Host "`n[SUCCESS] Windows ImDisk RAM-Disk is ready and configured for AmberDB!" -ForegroundColor Green
    Write-Host "  Project:      $ProjectName"
    Write-Host "  RAM Storage:  $projectRam"
    Write-Host "  Local Link:   $ramdiskDir -> $projectRam"
    Write-Host '  |-- tables/   (DB and Index acceleration files)'
    Write-Host '  |-- conf/     (Compiled config files)'
    Write-Host '  |-- schema/   (Table and DBase schema files)'
    Write-Host '  |-- lock/     (Flock lock files)'
    Write-Host "  \-- pids/     (Process and mutex files)`n"
}
