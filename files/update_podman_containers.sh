#!/bin/bash
set -euo pipefail

LOGDIR="/var/log/podman-updates"
mkdir -p "$LOGDIR"

LAN_IFACE="br0"        # VRRP interface
VIP="fd00:1::1"        # VRRP virtual IPv6 address

LASTRUN="$LOGDIR/last-run.log"
: > "$LASTRUN"
echo "Last update run: $(date)" >> "$LASTRUN"
echo >> "$LASTRUN"

function status() {
    echo "$1" >> "$LASTRUN"
}

function is_master() {
    ip -6 addr show "$LAN_IFACE" | grep -q "$VIP"
}

function pull_and_reboot() {
    local name="$1"
    local cfgdir="$HOME/docker-compose-configs/$name"
    local compose="$cfgdir/docker-compose.yml"

    local logf="$LOGDIR/${name}.log"
    : > "$logf"

    status "=== Updating $name ==="

    # Extract images
    local images
    images=$(grep -E "image:" "$compose" | awk '{print $2}' | sort -u)

    status "Images: $images"

    # Pull images
    for img in $images; do
        status "Pulling $img..."
        podman pull "$img" >> "$logf" 2>&1
    done

    # Restart stack
    status "Restarting $name..."
    cd "$cfgdir"
    podman-compose down >> "$logf" 2>&1
    podman-compose up -d --remove-orphans >> "$logf" 2>&1

    status "=== Done with $name ==="
    echo >> "$LASTRUN"
}

NORMAL_DIR="$HOME/containers-enabled/normal"
HA_DIR="$HOME/containers-enabled/ha"

normal_services=$(basename -a "$NORMAL_DIR"/* 2>/dev/null || true)
ha_services=$(basename -a "$HA_DIR"/* 2>/dev/null || true)

status "Normal services: $normal_services"
status "HA services: $ha_services"

# Update normal services on ALL hosts
for svc in $normal_services; do
    pull_and_reboot "$svc" &
done

# Update HA services ONLY on BACKUP
if is_master; then
    status "Skipping HA services on MASTER"
else
    status "Updating HA services on BACKUP"
    for svc in $ha_services; do
        pull_and_reboot "$svc" &
    done
fi

wait
status "All updates completed."
