#!/usr/bin/env bash

# Base ROS environment plus rootless dependencies installed under this workspace.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname -- "$SCRIPT_DIR")"

if [[ -f /opt/ros/humble/setup.bash ]]; then
  # shellcheck disable=SC1091
  source /opt/ros/humble/setup.bash
fi

LOCAL_ROS_PREFIX="$WORKSPACE_ROOT/.local/ros_deps/opt/ros/humble"
for package_setup in \
  "$LOCAL_ROS_PREFIX/share/gazebo_plugins/local_setup.bash" \
  "$LOCAL_ROS_PREFIX/share/pointcloud_to_laserscan/local_setup.bash"
do
  if [[ -f "$package_setup" ]]; then
    # shellcheck disable=SC1090
    source "$package_setup"
  fi
done

LOCAL_KISS_PREFIX="$WORKSPACE_ROOT/.local/kiss_matcher"
if [[ -d "$LOCAL_KISS_PREFIX" ]]; then
  export CMAKE_PREFIX_PATH="$LOCAL_KISS_PREFIX${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
fi

LOCAL_SMALL_GICP_PREFIX="$WORKSPACE_ROOT/.local/small_gicp"
if [[ -d "$LOCAL_SMALL_GICP_PREFIX" ]]; then
  export CMAKE_PREFIX_PATH="$LOCAL_SMALL_GICP_PREFIX${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
  export LD_LIBRARY_PATH="$LOCAL_SMALL_GICP_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

unset LOCAL_KISS_PREFIX LOCAL_ROS_PREFIX LOCAL_SMALL_GICP_PREFIX package_setup
