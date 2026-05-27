#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$HOME/docker-compose-configs"
ENABLED_DIR="$BASE_DIR/containers-enabled"
LOG_DIR="$HOME/container-logs"
mkdir -p "$LOG_DIR"

KEEPALIVED_ROLE_FILE="$BASE_DIR/keepalived_role"
ROLE="UNKNOWN"
if [[ -f "$KEEPALIVED_ROLE_FILE" ]]; then
    ROLE=$(cat "$KEEPALIVED_ROLE_FILE")
fi

# CASE 1: No args → update ALL linked containers
# CASE 2: Args → update ONLY those containers
if [[ $# -gt 0 ]]; then
    TARGET_CONTAINERS=("$@")
else
    TARGET_CONTAINERS=($(ls "$ENABLED_DIR"))
fi

echo "Host HA role: $ROLE"
echo "Updating containers (parallel): ${TARGET_CONTAINERS[*]}"

update_container() {
    local name="$1"
    local dir="$ENABLED_DIR/$name"

    # Skip if container is not linked/enabled
    if [[ ! -d "$dir" ]]; then
        echo "Skipping $name (not enabled on this host)"
        return
    fi

    # HA container logic
    if [[ -f "$dir/HA_CONTAINER" ]]; then
        if [[ "$ROLE" == "MASTER" ]]; then
            echo "Updating HA container $name (MASTER host, will NOT start)"
            (
                cd "$dir"
                podman-compose pull
            ) &> "$LOG_DIR/$name.log"
            return
        else
            echo "Updating HA container $name (BACKUP host, will start)"
            (
                cd "$dir"
                podman-compose pull
                podman-compose up -d
            ) &> "$LOG_DIR/$name.log"
            return
        fi
    fi

    # Non-HA container logic
    echo "Updating non-HA container $name"
    (
        cd "$dir"
        podman-compose pull
        podman-compose up -d
    ) &> "$LOG_DIR/$name.log"
}

# Run all updates in parallel
for c in "${TARGET_CONTAINERS[@]}"; do
    update_container "$c" &
done

wait

echo "All updates complete (parallel mode)."
