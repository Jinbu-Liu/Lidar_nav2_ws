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
MAP_DIR="$WORKSPACE_ROOT/src/me_nav2_bringup/map"
MAP_PREFIX="$MAP_DIR/$TIMESTAMP"

mkdir -p "$MAP_DIR"
if [[ -e "$MAP_PREFIX.yaml" || -e "$MAP_PREFIX.pgm" ]]; then
  echo "错误：同一时间戳的地图文件已存在：$MAP_PREFIX" >&2
  exit 1
fi

echo "正在保存 2D 地图：$MAP_PREFIX.yaml / $MAP_PREFIX.pgm"
ros2 run nav2_map_server map_saver_cli -f "$MAP_PREFIX"
