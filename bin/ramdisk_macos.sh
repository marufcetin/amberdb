#!/bin/bash
# bin/ramdisk_macos.sh - macOS Native APFS/HFS+ RAM-Disk Helper for AmberDB
# Uses macOS built-in hdiutil and diskutil (No external drivers required)
#
# Usage:
#   ./bin/ramdisk_macos.sh start [size] [project_name]
#   ./bin/ramdisk_macos.sh stop  [project_name]
#   ./bin/ramdisk_macos.sh status

set -e

ACTION="${1:-status}"
SIZE_RAW="${2:-512M}"
PROJECT_NAME="$3"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="$(basename "$PROJECT_DIR")"
fi

VOLUME_NAME="AmberDB_RAM"
VOLUME_PATH="/Volumes/$VOLUME_NAME"
PROJECT_RAM="$VOLUME_PATH/$PROJECT_NAME"
LOCAL_RAM="$PROJECT_DIR/dbstore/ramdisk"

calc_sectors() {
    local raw="$1"
    local num=$(echo "$raw" | grep -o -E '[0-9]+')
    local unit=$(echo "$raw" | tr '[:lower:]' '[:upper:]' | grep -o -E '[MGK]')

    if [ "$unit" == "G" ]; then
        echo $(( num * 1024 * 2048 ))
    elif [ "$unit" == "K" ]; then
        echo $(( num * 2 ))
    else
        # Default MB
        echo $(( num * 2048 ))
    fi
}

# --- Action: STATUS ---
if [ "$ACTION" == "status" ] || [ "$ACTION" == "--status" ]; then
    echo "================================================================="
    echo " AmberDB macOS RAM-Disk Status Monitor"
    echo "================================================================="
    echo "Platform:       macOS ($(sw_vers -productVersion 2>/dev/null || uname -s))"
    echo "Project Name:   $PROJECT_NAME"
    echo "Project Root:   $PROJECT_DIR"
    echo "Local RAM Path: $LOCAL_RAM"
    echo "RAM Volume:     $VOLUME_PATH"

    if [ -d "$VOLUME_PATH" ] && [ -d "$PROJECT_RAM" ]; then
        echo "RAM-Disk:       ACTIVE (Mounted on $PROJECT_RAM)"
    elif [ -d "$VOLUME_PATH" ]; then
        echo "RAM-Disk:       VOLUME ACTIVE ($VOLUME_PATH mounted, project $PROJECT_NAME not initialized)"
    else
        echo "RAM-Disk:       INACTIVE (Running on local storage)"
    fi
    echo "================================================================="
    exit 0
fi

# --- Action: STOP / UNMOUNT ---
if [ "$ACTION" == "stop" ] || [ "$ACTION" == "--stop" ] || [ "$ACTION" == "unmount" ]; then
    echo "[RAM-DISK] Stopping AmberDB RAM-Disk for project '$PROJECT_NAME'..."

    # 1. Remove local symlink and restore empty dirs
    if [ -L "$LOCAL_RAM" ]; then
        rm -f "$LOCAL_RAM"
        mkdir -p "$LOCAL_RAM"/{tables,conf,schema,lock,pids}
    fi

    # 2. Clean project folder from RAM disk
    if [ -d "$PROJECT_RAM" ]; then
        rm -rf "$PROJECT_RAM"
    fi

    # 3. Detach volume if no other project folders remain
    if [ -d "$VOLUME_PATH" ]; then
        REMAINING=$(find "$VOLUME_PATH" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | grep -v "^\." | wc -l | tr -d ' ')
        if [ "$REMAINING" -eq "0" ]; then
            echo "[RAM-DISK] No other projects active. Detaching RAM-Disk $VOLUME_PATH..."
            hdiutil detach "$VOLUME_PATH" -force 2>/dev/null || true
        fi
    fi

    echo "[SUCCESS] macOS RAM-Disk unmounted and restored to local storage for '$PROJECT_NAME'."
    exit 0
fi

# --- Action: START / MOUNT ---
if [ "$ACTION" == "start" ] || [ "$ACTION" == "--start" ] || [ "$ACTION" == "mount" ]; then
    echo "[RAM-DISK] Initializing macOS APFS RAM-Disk for '$PROJECT_NAME' ($SIZE_RAW)..."

    SECTORS=$(calc_sectors "$SIZE_RAW")

    # 1. Mount RAM disk block device if volume not already present
    if [ ! -d "$VOLUME_PATH" ]; then
        echo "[RAM-DISK] Allocating $SECTORS sectors via hdiutil..."
        RAMDEV=$(hdiutil attach -nomount "ram://$SECTORS" | tr -d '[:space:]')
        
        echo "[RAM-DISK] Formatting $RAMDEV with APFS as '$VOLUME_NAME'..."
        diskutil eraseVolume APFS "$VOLUME_NAME" "$RAMDEV" >/dev/null 2>&1 || \
        diskutil eraseVolume HFS+ "$VOLUME_NAME" "$RAMDEV" >/dev/null
    fi

    # 2. Create isolated project folder on RAM volume
    mkdir -p "$PROJECT_RAM"/{tables,conf,schema,lock,pids}

    # 3. Link dbstore/ramdisk to /Volumes/AmberDB_RAM/<ProjectName>
    if [ -e "$LOCAL_RAM" ]; then
        rm -rf "$LOCAL_RAM"
    fi
    mkdir -p "$(dirname "$LOCAL_RAM")"
    ln -sfn "$PROJECT_RAM" "$LOCAL_RAM"

    echo ""
    echo "[SUCCESS] macOS RAM-Disk is ready and configured for AmberDB!"
    echo "  Project:      $PROJECT_NAME"
    echo "  RAM Storage:  $PROJECT_RAM"
    echo "  Local Link:   $LOCAL_RAM -> $PROJECT_RAM"
    echo "  ├── tables/   (DB & Index acceleration files)"
    echo "  ├── conf/     (Compiled config files)"
    echo "  ├── schema/   (Table & DBase schema files)"
    echo "  ├── lock/     (Flock lock files)"
    echo "  └── pids/     (Process & mutex files)"
    echo ""
    exit 0
fi
