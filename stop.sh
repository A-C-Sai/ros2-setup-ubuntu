#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# stop.sh — Native Linux edition (Docker, no VM layer)
# =============================================================================

rm -rf build install log .vscode

echo "Stopping container..."
docker stop ros2_jazzy 2>/dev/null || true

echo "Waiting for container to be removed to delete image..."
while docker ps -a --format '{{.Names}}' | grep -q "^ros2_jazzy$"; do
	sleep 1
done
sleep 5

echo "Deleting image..."
docker rmi $(docker images --format '{{.Repository}}:{{.Tag}}' | grep "^vsc-") 2>/dev/null || true

echo "Revoking local X server access..."
xhost -local:docker > /dev/null 2>&1 || true

echo "Done."
