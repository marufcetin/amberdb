@echo off
rem bin/ramdisk_windows.bat - Windows ImDisk RAM-Disk Helper for AmberDB
rem Run with Administrator privileges

set ACTION=status
if "%1"=="start" set ACTION=start
if "%1"=="--start" set ACTION=start
if "%1"=="mount" set ACTION=start
if "%1"=="stop" set ACTION=stop
if "%1"=="--stop" set ACTION=stop
if "%1"=="unmount" set ACTION=stop
if "%1"=="status" set ACTION=status
if "%1"=="--status" set ACTION=status

set SIZE=512M
if not "%2"=="" set SIZE=%2

set PROJECT_NAME=
if not "%3"=="" set PROJECT_NAME=%3

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ramdisk_windows.ps1" -Action %ACTION% -Size %SIZE% -ProjectName "%PROJECT_NAME%"
