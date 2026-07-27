# ROS2 Jazzy Dev Container — Native Linux (Ubuntu 24.04) + Docker

Dev Container setup for ROS2 Jazzy development with direct USB access to a
Dynamixel motor via an OpenRB-150 board. Runs on native Linux, so there's no
VM layer between the container and your hardware — unlike Docker Desktop on
macOS, USB and X11 passthrough both just work here.

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Builds the ROS2 Jazzy image (VirtualGL, ros2_control, Dynamixel SDK, pyserial) |
| `devcontainer.json` | VS Code Dev Containers config — mounts the USB device and X11 socket |
| `start.sh` | Pre-flight checks: X11 access, USB device present, dialout group, Docker running |
| `stop.sh` | Cleans up the container, image, and build artifacts |

Place `Dockerfile` and `devcontainer.json` inside a `.devcontainer/` folder at
the root of your project; keep `start.sh` and `stop.sh` at the project root.

```
your-project/
├── .devcontainer/
│   ├── Dockerfile
│   └── devcontainer.json
├── start.sh
├── stop.sh
└── src/
```

## One-time setup

### 1. Install Docker

```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable --now docker

# Let your user run docker without sudo
sudo usermod -aG docker $USER
```

**Log out and back in** (or `newgrp docker`) for the group change to take effect.

### 2. Install VS Code

```bash
sudo snap install code --classic
```

### 3. Install the Dev Containers extension

```bash
code --install-extension ms-vscode-remote.remote-containers
```

### 4. Add yourself to the `dialout` group

Required so your user (and the container, via `--group-add=dialout`) can
read/write the serial device without root:

```bash
sudo usermod -aG dialout $USER
```

**Log out and back in** for this to take effect. Verify with:

```bash
groups | grep dialout
```

### 5. Set up git and SSH (if not already done)

```bash
sudo apt install -y git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

ssh-keygen -t ed25519 -C "your.email@example.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub   # add this to GitHub/GitLab → Settings → SSH keys
ssh -T git@github.com       # test
```

### 6. Install GUI/X11 support

Needed for RViz, Gazebo, rqt, and other windowed ROS2 tools launched from the
container. On native Linux, the container talks to your host's X server
directly (via `--network=host` and the `/tmp/.X11-unix` mount in
`devcontainer.json`) — no XQuartz or network forwarding tricks required.

```bash
sudo apt install -y x11-apps mesa-utils
```

Verify your host is using real GPU rendering (not the `llvmpipe` software
fallback), which matters for anything 3D like Gazebo/RViz:

```bash
glxinfo | grep "OpenGL renderer"
```

**Note on VirtualGL:** the Dockerfile still installs VirtualGL and configures
`vglclient`/`VGL_DISPLAY` in `.bashrc`, carried over from the original macOS
setup. On this local native-Linux setup it's installed but unused — your GPU
is reached directly through the mounted X11 socket, no interception needed.
It's left in place so this same image can be reused later on a remote or
headless Linux box, where `vglrun`-wrapped GPU-accelerated rendering over the
network would actually be needed.

## GUI Support Summary

| Scenario | What's used |
|---|---|
| Local native Linux (this setup) | Host X server via `--network=host` + `/tmp/.X11-unix` mount. Direct GPU access, no VirtualGL needed. |
| Remote/headless Linux box (future) | Would need `vglclient`/`vglrun` (already installed) plus `DISPLAY` forwarding back to your local machine over SSH or network. Not configured in the current `devcontainer.json` — ask if you need this variant. |
| macOS (Docker Desktop / Podman) | XQuartz + VirtualGL, since the VM's virtual display has no real GPU — see the "Why this setup differs from macOS" section above. |



1. Plug in the OpenRB-150 (with the Dynamixel motor attached).
2. Run the pre-flight script:
   ```bash
   ./start.sh
   ```
   This checks that:
   - your X server will accept connections from Docker containers
   - `/dev/ttyACM0` (or similar) is present
   - your user is in the `dialout` group
   - the Docker daemon is running and reachable

   Fix any warnings it prints before continuing.

3. Open the project folder in VS Code, then `Ctrl+Shift+P` →
   **Dev Containers: Reopen in Container** (first time, or after editing the
   Dockerfile, use **Rebuild and Reopen in Container**).

4. Once inside the container, verify the device is visible:
   ```bash
   ls -la /dev/ttyACM0
   ```
   Test with Python:
   ```python
   import serial
   s = serial.Serial('/dev/ttyACM0', 57600)
   print(s.name)
   ```
   Or use the Dynamixel SDK (already installed in the image) for
   read/write/ping against the motor.

5. When done, close VS Code and run:
   ```bash
   ./stop.sh
   ```
   This stops/removes the container, deletes the built image, cleans up
   `build/install/log/.vscode` artifacts, and revokes the X11 access grant.

## Why this setup differs from macOS

On macOS, Docker Desktop (and Podman) run containers inside a hidden Linux VM.
Docker Desktop has no supported USB passthrough at all, and as of Podman 5.x,
the macOS `applehv` provider dropped USB passthrough support too (QEMU, which
used to support it, is no longer available as a macOS provider).

On native Linux, there is no VM: Docker talks to the kernel directly, so
`--device=/dev/ttyACM0` in `runArgs` just works, and there's no networking
workaround needed for GUI apps either — the container shares the host's X11
socket and network namespace directly (`--network=host`).

## Docker vs. Podman on native Linux

Both work identically here — same direct kernel access, same `--device` flag,
same result. The only meaningful differences:
- Docker uses a background daemon (`dockerd`) running as root by default;
  Podman is daemonless and rootless by default.
- Docker's `--group-add=dialout` needs the group name/GID explicitly; Podman
  has a `--group-add=keep-groups` shortcut that carries over all your host
  groups automatically.
- Dockerfiles, `docker build`, and `docker run` syntax are what Podman
  deliberately mirrors — so switching between them later is low-friction if
  you ever want to.

## Troubleshooting

**`/dev/ttyACM0` not found**
- Confirm the OpenRB-150 is plugged in and powered: `dmesg | tail -20`
  should show a new CDC-ACM device on connect.
- The device path can shift (e.g. to `ttyACM1`) if other serial devices are
  connected. Check with `ls /dev/ttyACM*` and update `devcontainer.json`'s
  `--device` flag accordingly, or add a udev rule for a stable symlink:
  ```bash
  echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="0069", SYMLINK+="openrb150"' | \
      sudo tee /etc/udev/rules.d/99-openrb150.rules
  sudo udevadm control --reload-rules
  ```
  (Replace the vendor/product IDs with your board's actual values from
  `lsusb`.) Then use `/dev/openrb150` in place of `/dev/ttyACM0`.

**Permission denied on the serial device**
- Make sure you've logged out/in after `usermod -aG dialout $USER`.
- Confirm `--group-add=dialout` is present in `devcontainer.json`'s `runArgs`.

**"permission denied" connecting to the Docker daemon**
- Make sure you've logged out/in after `usermod -aG docker $USER`.
- Confirm the daemon is running: `sudo systemctl status docker`.

**GUI apps (RViz, Gazebo, rqt) don't display**
- Confirm `start.sh` ran `xhost +local:docker` without error.
- Confirm `$DISPLAY` is set on the host before launching VS Code:
  `echo $DISPLAY` should print something like `:0` or `:1`.

**GUI apps display but are slow / choppy (3D views especially)**
- Run `glxinfo | grep "OpenGL renderer"` on the host. If it shows `llvmpipe`
  instead of your actual GPU model, you're on software rendering — check
  that your GPU drivers are installed correctly (`nvidia-smi` for NVIDIA,
  or `sudo apt install mesa-vulkan-drivers` for Intel/AMD).
- This is a host-level issue, not something the container config can fix.

**Container won't build / rebuild picks up stale layers**
- Use **Dev Containers: Rebuild Without Cache and Reopen in Container** from
  the VS Code command palette.
