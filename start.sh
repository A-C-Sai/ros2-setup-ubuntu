#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# start.sh — Native Linux edition (Docker, no VM layer)
# Purpose: On native Linux, Docker talks to the kernel directly (no VM), so
#          there's no passthrough config needed. This script just does sanity
#          checks before you open VS Code.
# =============================================================================

echo "Allowing local containers to connect to the X server..."
xhost +local:docker > /dev/null 2>&1 || echo "WARNING: xhost not found or X server not running (are you in a GUI session?)"

echo "Checking for the OpenRB-150 serial device..."
if ls /dev/ttyACM* > /dev/null 2>&1; then
    ls -la /dev/ttyACM*
else
    echo "WARNING: no /dev/ttyACM* device found. Is the OpenRB-150 plugged in?"
fi

echo "Checking that your user has serial (dialout) permissions..."
if groups | grep -q dialout; then
    echo "OK: current user is in the dialout group."
else
    echo "WARNING: current user is NOT in the dialout group yet."
    echo "  Run: sudo usermod -aG dialout \$USER"
    echo "  Then log out and back in for it to take effect."
fi

echo "Checking that Docker is available and the daemon is running..."
docker --version || { echo "ERROR: docker not found. Install with: sudo apt install docker.io"; exit 1; }
docker info > /dev/null 2>&1 || {
    echo "ERROR: Docker daemon isn't reachable. Try: sudo systemctl start docker"
    echo "       Also make sure your user is in the 'docker' group: sudo usermod -aG docker \$USER"
    exit 1
}

echo "Done. You can now open VS Code and 'Reopen in Container'."
