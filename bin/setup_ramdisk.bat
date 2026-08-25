@echo off
rem bin/setup_ramdisk.bat - Windows ImDisk RAM-Disk Helper for AmberDB
rem Run as Administrator!

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Administrator privileges required!
    echo Please right-click this script and select 'Run as administrator'.
    pause
    exit /b 1
)

set DRIVE=R:
set SIZE=512M

if "%1"=="--stop" goto stop_ramdisk
if "%1"=="stop" goto stop_ramdisk
if "%1"=="-stop" goto stop_ramdisk

if "%1"=="--size" if not "%2"=="" (
    set SIZE=%2
) else if "%1"=="-s" if not "%2"=="" (
    set SIZE=%2
) else if not "%1"=="" (
    set SIZE=%1
)

echo [RAM-DISK] Starting ImDisk RAM-Disk on %DRIVE% (%SIZE%)...
where imdisk.exe >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] ImDisk is not installed!
    echo To install ImDisk:
    echo   1. Chocolatey: choco install ImDisk-Toolkit
    echo   2. Direct Download: https://sourceforge.net/projects/imdisk-toolkit/
    pause
    exit /b 1
)

if not exist %DRIVE%\ (
    imdisk -a -s %SIZE% -m %DRIVE% -p "/fs:ntfs /q /y"
)

mkdir %DRIVE%\tables 2>nul
mkdir %DRIVE%\conf 2>nul
mkdir %DRIVE%\scheme 2>nul
mkdir %DRIVE%\lock 2>nul
mkdir %DRIVE%\pids 2>nul

set PROJECT_DIR=%~dp0..
set CACHE_DIR=%PROJECT_DIR%\dbstore\cache
set LOCK_DIR=%PROJECT_DIR%\dbstore\lock

if exist "%LOCK_DIR%" rmdir /s /q "%LOCK_DIR%" 2>nul
if exist "%CACHE_DIR%" rmdir /s /q "%CACHE_DIR%" 2>nul
mklink /J "%CACHE_DIR%" "%DRIVE%\"

echo [SUCCESS] Windows ImDisk RAM-Disk linked to AmberDB!
echo   Cache Root: %CACHE_DIR% -^> %DRIVE%\
echo   ├── tables/  (DB ^& Index cache)
echo   ├── conf/    (Compiled config cache)
echo   ├── scheme/  (Table ^& DBase schema cache)
echo   ├── lock/    (Flock lock files)
echo   └── pids/    (Process ^& mutex files)
goto end

:stop_ramdisk
echo [RAM-DISK] Stopping ImDisk RAM-Disk...
set PROJECT_DIR=%~dp0..
set CACHE_DIR=%PROJECT_DIR%\dbstore\cache

rmdir "%CACHE_DIR%" 2>nul
mkdir "%CACHE_DIR%" 2>nul
mkdir "%CACHE_DIR%\tables" 2>nul
mkdir "%CACHE_DIR%\conf" 2>nul
mkdir "%CACHE_DIR%\scheme" 2>nul
mkdir "%CACHE_DIR%\lock" 2>nul
mkdir "%CACHE_DIR%\pids" 2>nul

imdisk -D -m %DRIVE% 2>nul
echo [SUCCESS] RAM-Disk unmounted.

:end
