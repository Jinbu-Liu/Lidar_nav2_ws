#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname -- "$SCRIPT_DIR")"
cd "$WORKSPACE_ROOT" || exit 1

# shellcheck disable=SC1091
source "$SCRIPT_DIR/setup_env.sh"
if [[ ! -f "$WORKSPACE_ROOT/install/setup.bash" ]]; then
  echo "错误：未找到 install/setup.bash，请先运行 ./scripts/build.sh" >&2
  exit 1
fi
# shellcheck disable=SC1091
source "$WORKSPACE_ROOT/install/setup.bash"

set -euo pipefail

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
PCD_DIR="$WORKSPACE_ROOT/src/me_nav2_bringup/pcd"
PCD_PATH="$PCD_DIR/$TIMESTAMP.pcd"

mkdir -p "$PCD_DIR"
if [[ -e "$PCD_PATH" ]]; then
  echo "错误：同一时间戳的 PCD 文件已存在：$PCD_PATH" >&2
  exit 1
fi

if ! ros2 param set /laser_mapping map_file_path "$PCD_PATH"; then
  echo "错误：无法设置 FAST-LIO 保存路径，请确认 /laser_mapping 节点正在运行" >&2
  exit 1
fi

echo "正在保存 3D 点云：$PCD_PATH"
ros2 service call /map_save std_srvs/srv/Trigger

if [[ ! -s "$PCD_PATH" ]]; then
  echo "错误：保存服务已返回，但未生成有效 PCD 文件：$PCD_PATH" >&2
  exit 1
fi

echo "PCD 保存完成：$PCD_PATH"
