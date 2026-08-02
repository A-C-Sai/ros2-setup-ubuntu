# =============================================================================
# ROS2 Jazzy Desktop Dev Container
# Base: osrf/ros:jazzy-desktop-full-noble (Ubuntu 24.04 Noble + ROS2 Jazzy)
# Purpose: Full ROS2 development environment with GPU/display forwarding via VirtualGL
# =============================================================================
FROM osrf/ros:jazzy-desktop-full-noble

# Delete user if it exists in container (e.g Ubuntu Noble: ubuntu)
RUN if id -u 1000 2>/dev/null; then userdel -r `id -un 1000`; fi

# -----------------------------------------------------------------------------
# Section 1: Environment Variables
# Purpose: Set default ROS distribution and ensure non-interactive apt installs
# -----------------------------------------------------------------------------
ENV ROS_DISTRO=jazzy
ENV DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# Section 2: System Updates & Core Utilities
# Purpose: Bring system packages up to date and install essential tools
# Note: linux-headers-generic are required for VirtualGL kernel module support/ integration
# -----------------------------------------------------------------------------

RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y \
        sudo \
        wget \
        nano \
        gedit \
        xvfb \
        linux-headers-generic \
	tree \
	less

# -----------------------------------------------------------------------------
# Section 3: VirtualGL Repository Setup & Installation
# Purpose: Enable GPU-accelerated OpenGL rendering inside the container
#          VirtualGL intercepts OpenGL calls and routes them through a virtual display
# Xvfb :1 creates a virtual framebuffer (1920x1080, 24-bit color) on display :1
# -----------------------------------------------------------------------------
RUN wget -q -O- https://packagecloud.io/dcommander/virtualgl/gpgkey | \
        gpg --dearmor > /etc/apt/trusted.gpg.d/VirtualGL.gpg && \
    wget -q -O /etc/apt/sources.list.d/VirtualGL.list \
        https://raw.githubusercontent.com/VirtualGL/repo/main/VirtualGL.list && \
    apt-get update -y && \
    apt-get install -y virtualgl

# -----------------------------------------------------------------------------
# Section 4: ROS2 Package Installation
# Purpose: Install all required ROS2 packages for robotics development:
#   - ros-gz:           Gazebo simulation integration
#   - gz-ros2-control:  Gazebo + ros2_control bridge
#   - moveit:           Motion planning framework
#   - joint-state-publisher-gui: GUI for visualizing/controlling joints in RViz
#   - xacro:            XML macro language for URDF robot models
#   - ros2-control/controllers: Hardware abstraction & controller manager
#   - libserial-dev:    Serial port communication (custom hardware/sensors)
#   - python3-pip:      Python package manager for ROS2 Python packages
# -----------------------------------------------------------------------------
RUN apt-get update -y && apt-get install -y \
        ros-${ROS_DISTRO}-ros-gz* \
		ros-${ROS_DISTRO}-*-ros2-control \
		ros-${ROS_DISTRO}-turtlesim \
		ros-${ROS_DISTRO}-robot-localization \
		ros-${ROS_DISTRO}-joy \
		ros-${ROS_DISTRO}-joy-linux
		ros-${ROS_DISTRO}-joy-teleop \
		ros-${ROS_DISTRO}-teleop-twist-joy \
		ros-${ROS_DISTRO}-tf-transformations \
        ros-${ROS_DISTRO}-gz-ros2-control \
        ros-${ROS_DISTRO}-gz-ros2-control-demos \
        ros-${ROS_DISTRO}-joint-state-publisher-gui \
        ros-${ROS_DISTRO}-moveit \
		ros-${ROS_DISTRO}-moveit-py \
        ros-${ROS_DISTRO}-xacro \
        ros-${ROS_DISTRO}-ros2-control \
        ros-${ROS_DISTRO}-ros2-controllers \
        ros-${ROS_DISTRO}-urdf-tutorial \
		ros-${ROS_DISTRO}-turtlebot* \
		ros-${ROS_DISTRO}-navigation2 \
		ros-${ROS_DISTRO}-nav2-bringup \
		ros-${ROS_DISTRO}-nav2-minimal-tb* \
        ros-${ROS_DISTRO}-dynamixel-sdk* \
		ros-${ROS_DISTRO}-slam-toolbox \
		ros-${ROS_DISTRO}-moveit \
		ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
        libserial-dev \
        python3-pip \
        python3-transforms3d \
		joystick \
		jstest-gtk \
		evtest

# -----------------------------------------------------------------------------
# Section 4b: Dynamixel / Serial Hardware Libraries
# Purpose: Install the Python libraries needed to talk to the Dynamixel motors
#          through the OpenRB-150 over USB serial (/dev/ttyACM0).
#   - pyserial:      low-level serial port access
#   - dynamixel-sdk: ROBOTIS SDK for Dynamixel motor control
# --break-system-packages needed on Ubuntu Noble's externally-managed Python
# -----------------------------------------------------------------------------
# RUN pip3 install --break-system-packages pyserial dynamixel-sdk

# -----------------------------------------------------------------------------
# Section 5: Non-Root User Creation
# Purpose: Run container as a non-root user for security best practices and
#          to match host filesystem permissions when using bind mounts
# User: jazzy (no password)
# Full sudo rights: (ALL : ALL) ALL — mirrors the 'ubuntu' user pattern in this image
#
# dialout group: added so 'jazzy' has read/write access to serial devices
#                (/dev/ttyACM0, /dev/ttyUSB0) once the OpenRB-150 / Dynamixel
#                USB device is passed through the Podman machine. Without this,
#                the --device flag alone can still yield "Permission denied"
#                depending on how the device node's group ownership lands
#                inside the VM.
# -----------------------------------------------------------------------------
RUN useradd -m -s /bin/bash jazzy && \
    passwd -d jazzy && \
    echo "jazzy ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    usermod -aG dialout,root,input jazzy

# -----------------------------------------------------------------------------
# Section 6: User Environment Configuration (~/.bashrc)
# Purpose: Configure the shell environment for the jazzy user:
#   - Source ROS2 setup so all ros2/colcon commands are available
#   - Source workspace overlay once built (ros_ws typo kept intentional
#     to match the spec; update path once workspace name is confirmed)
#   - Display forwarding: route GUI apps to host X server (XQuartz/VcXsrv)
#   - VirtualGL: route OpenGL to in-container virtual display :1
#   - build alias: one-command workspace rebuild + source
# -----------------------------------------------------------------------------
RUN echo "# ── ROS2 Environment ──────────────────────────────────────────────" >> /home/jazzy/.bashrc && \
	echo "export ROS_DOMAIN_ID=42"                                             >> /home/jazzy/.bashrc && \
    echo "export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST"                      >> /home/jazzy/.bashrc && \
	echo "export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp"                      >> /home/jazzy/.bashrc && \
    echo "source /opt/ros/jazzy/setup.bash"                                    >> /home/jazzy/.bashrc && \
    echo ""                                                                    >> /home/jazzy/.bashrc && \
    echo "# Source workspace overlay (populated after first colcon build)"     >> /home/jazzy/.bashrc && \
    echo '[ -f /workspaces/*/install/setup.bash ] && source /workspaces/*/install/setup.bash' >> /home/jazzy/.bashrc && \
    echo ""                                                                    >> /home/jazzy/.bashrc && \
    echo "# ── Display / GPU Forwarding ───────────────────────────────────────" >> /home/jazzy/.bashrc && \
    echo "# DISPLAY is supplied by devcontainer.json's containerEnv (\${localEnv:DISPLAY})" >> /home/jazzy/.bashrc && \
    echo "# not hardcoded here — native Linux X11 doesn't use host.docker.internal"       >> /home/jazzy/.bashrc && \
    echo "# VirtualGL vars only needed for remote/headless rendering — set manually if used" >> /home/jazzy/.bashrc && \
    echo ""                                                                    >> /home/jazzy/.bashrc && \
    echo "# ── Set up colcon_cd and colcon tab completion ───────────────────--" >> /home/jazzy/.bashrc && \
    echo "source /usr/share/colcon_cd/function/colcon_cd.sh"                   >> /home/jazzy/.bashrc && \
    echo 'export _colcon_cd_root=$(echo /workspaces/*/)'                            >> /home/jazzy/.bashrc && \
    echo "source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash"   >> /home/jazzy/.bashrc && \
    echo "source /usr/share/colcon_cd/function/colcon_cd-argcomplete.bash"     >> /home/jazzy/.bashrc && \
    echo ""                                                                    >> /home/jazzy/.bashrc && \
    echo "# Start Xvfb virtual framebuffer if not already running (required for VirtualGL/OpenGL rendering)" >> /home/jazzy/.bashrc && \
    echo "pgrep Xvfb > /dev/null || Xvfb :1 -screen 0 1920x1080x24 +extension GLX &>/dev/null &" >> /home/jazzy/.bashrc && \
    echo ""                                                                    >> /home/jazzy/.bashrc && \
    echo "# ── Convenience Aliases ───────────────────────────────────────────-" >> /home/jazzy/.bashrc && \
    echo 'alias build="cd /workspaces/*/ && rosdep update && sudo rosdep install -i --from-path src --rosdistro jazzy -y && colcon build && source ~/.bashrc"'      >> /home/jazzy/.bashrc && \
    echo 'bind '\''"\C-xz": alias-expand-line'\'''       >> /home/jazzy/.bashrc && \
    chown -R jazzy:jazzy /home/jazzy

# -----------------------------------------------------------------------------
# Section 7: Default User & Working Directory
# Purpose: All container sessions start as jazzy in the ros2_ws directory
#          (the bind-mounted host workspace)
# -----------------------------------------------------------------------------
USER jazzy
