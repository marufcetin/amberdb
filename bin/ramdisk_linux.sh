#!/bin/bash
# bin/ramdisk_linux.sh - Linux tmpfs RAM-Disk Helper for AmberDB
# Run with sudo privileges (or via ramdisk_amberdb.pl)
#
# Usage:
#   sudo ./bin/ramdisk_linux.sh start [size] [project_name]
#   sudo ./bin/ramdisk_linux.sh stop  [project_name]
#   ./bin/ramdisk_linux.sh status

set -e

ACTION="${1:-status}"
SIZE="${2:-512M}"
PROJECT_NAME="$3"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="$(basename "$PROJECT_DIR")"
fi

LOCAL_RAM="$PROJECT_DIR/dbstore/ramdisk"

# --- Action: STATUS ---
if [ "$ACTION" == "status" ] || [ "$ACTION" == "--status" ]; then
    echo "================================================================="
    echo " AmberDB Linux RAM-Disk Status Monitor"
    echo "================================================================="
    echo "Platform:       Linux ($(uname -r))"
    echo "Project Name:   $PROJECT_NAME"
    echo "Project Root:   $PROJECT_DIR"
    echo "RAM-Disk Path:  $LOCAL_RAM"

    if [ -L "$LOCAL_RAM" ]; then
        LINK_TARGET=$(readlink "$LOCAL_RAM" 2>/dev/null || true)
        echo "RAM-Disk:       ACTIVE (Symlink -> $LINK_TARGET)"
    elif mount | grep -q "$LOCAL_RAM.*tmpfs"; then
        MOUNT_INFO=$(mount | grep "$LOCAL_RAM.*tmpfs" | awk '{print $1, $4, $5, $6}')
        echo "RAM-Disk:       ACTIVE (tmpfs mounted on $LOCAL_RAM)"
        echo "Details:        $MOUNT_INFO"
    else
        echo "RAM-Disk:       INACTIVE (Running on local storage)"
    fi
    echo "================================================================="
    exit 0
fi

# Root check for start / stop
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Root privileges required! Please run with sudo: sudo $0 $ACTION"
    exit 1
fi

# --- Action: STOP / UNMOUNT ---
if [ "$ACTION" == "stop" ] || [ "$ACTION" == "--stop" ] || [ "$ACTION" == "unmount" ]; then
    echo "[RAM-DISK] Stopping AmberDB RAM-Disk for project '$PROJECT_NAME'..."

    if mount | grep -q "$LOCAL_RAM.*tmpfs"; then
        umount "$LOCAL_RAM" 2>/dev/null || umount -l "$LOCAL_RAM" 2>/dev/null
    fi

    mkdir -p "$LOCAL_RAM"/{tables,conf,schema,lock,pids}
    echo "[SUCCESS] Linux tmpfs RAM-Disk unmounted and restored to local storage for '$PROJECT_NAME'."
    exit 0
fi

# --- Action: START / MOUNT ---
if [ "$ACTION" == "start" ] || [ "$ACTION" == "--start" ] || [ "$ACTION" == "mount" ]; then
    echo "[RAM-DISK] Mounting Linux tmpfs RAM-Disk for '$PROJECT_NAME' ($SIZE)..."

    mkdir -p "$LOCAL_RAM"

    if ! mount | grep -q "$LOCAL_RAM.*tmpfs"; then
        mount -t tmpfs -o size="$SIZE",mode=0777 tmpfs "$LOCAL_RAM"
    fi

    mkdir -p "$LOCAL_RAM"/{tables,conf,schema,lock,pids}
    chmod -R 0777 "$LOCAL_RAM" 2>/dev/null || true

    echo ""
    echo "[SUCCESS] Linux tmpfs RAM-Disk mounted and configured for AmberDB!"
    echo "  Project:      $PROJECT_NAME"
    echo "  RAM Storage:  $LOCAL_RAM ($SIZE)"
    echo "  ├── tables/   (DB & Index acceleration files)"
    echo "  ├── conf/     (Compiled config files)"
    echo "  ├── schema/   (Table & DBase schema files)"
    echo "  ├── lock/     (Flock lock files)"
    echo "  └── pids/     (Process & mutex files)"
    echo ""
    exit 0
fi
