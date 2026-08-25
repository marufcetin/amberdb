#!/bin/bash
# bin/setup_ramdisk.sh - Linux tmpfs RAM-Disk Helper for AmberDB
# Run with sudo!

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Root privileges required! Please run with sudo."
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$PROJECT_DIR/dbstore/cache"
SIZE="512M"

if [ "$1" == "--stop" ] || [ "$1" == "stop" ]; then
    echo "[RAM-DISK] Unmounting tmpfs for AmberDB..."
    umount "$CACHE_DIR" 2>/dev/null
    mkdir -p "$CACHE_DIR"/{tables,conf,scheme,lock,pids}
    echo "[SUCCESS] tmpfs unmounted."
    exit 0
fi

if [ "$1" == "--size" ] || [ "$1" == "-s" ]; then
    if [ -n "$2" ]; then
        SIZE="$2"
    fi
elif [ -n "$1" ]; then
    SIZE="$1"
fi

echo "[RAM-DISK] Mounting tmpfs for AmberDB ($SIZE)..."
mkdir -p "$CACHE_DIR"

mount -t tmpfs -o size=$SIZE,mode=0777 tmpfs "$CACHE_DIR"

mkdir -p "$CACHE_DIR"/{tables,conf,scheme,lock,pids}

echo "[SUCCESS] Linux tmpfs RAM-Disk mounted!"
echo "  Cache Root: $CACHE_DIR ($SIZE)"
echo "  ├── tables/  (DB & Index cache)"
echo "  ├── conf/    (Compiled config cache)"
echo "  ├── scheme/  (Table & DBase schema cache)"
echo "  ├── lock/    (Flock lock files)"
echo "  └── pids/    (Process & mutex files)"
