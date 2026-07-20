#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname -- "$SCRIPT_DIR")"

if [[ -f /opt/ros/humble/setup.bash ]]; then
  # shellcheck disable=SC1091
  source /opt/ros/humble/setup.bash
fi

set -u

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
elif [[ $# -gt 0 ]]; then
  echo "用法：$0 [--dry-run]" >&2
  exit 2
fi

# Match project-installed nodes, system ROS nodes, ros2 CLI processes, and
# Gazebo Classic processes. This intentionally includes ROS nodes outside this
# workspace when the current user has permission to terminate them.
PROCESS_PATTERNS=(
  "$WORKSPACE_ROOT/install/"
  "/opt/ros/humble/lib/"
  "/opt/ros/humble/bin/ros2( |$)"
  "(^|/)gzserver( |$)"
  "(^|/)gzclient( |$)"
)

signal_matches() {
  local signal_name="$1"
  local pattern="$2"
  local pids=()

  mapfile -t pids < <(pgrep -f -- "$pattern" || true)
  if [[ ${#pids[@]} -eq 0 ]]; then
    return
  fi

  echo "[$signal_name] $pattern -> PID: ${pids[*]}"
  if [[ "$DRY_RUN" == false ]]; then
    kill "-$signal_name" "${pids[@]}" 2>/dev/null || true
  fi
}

if [[ "$DRY_RUN" == true ]]; then
  echo "仅预览，不会终止进程。"
else
  echo "正在关闭当前用户可终止的所有 ROS Humble 节点及 Gazebo 进程……"
fi

for pattern in "${PROCESS_PATTERNS[@]}"; do
  signal_matches TERM "$pattern"
done

if [[ "$DRY_RUN" == false ]]; then
  sleep 2
  for pattern in "${PROCESS_PATTERNS[@]}"; do
    signal_matches KILL "$pattern"
  done

  if command -v ros2 >/dev/null 2>&1; then
    ros2 daemon stop >/dev/null 2>&1 || true
  fi
  echo "ROS 2、当前项目节点和 Gazebo 进程已关闭。"
fi
