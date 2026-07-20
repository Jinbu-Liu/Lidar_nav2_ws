#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname -- "$SCRIPT_DIR")"
cd "$WORKSPACE_ROOT" || exit 1

# shellcheck disable=SC1091
source "$SCRIPT_DIR/setup_env.sh"

CMAKE_ARGS=(
  -DCMAKE_BUILD_TYPE=Release
  -DBUILD_CUDA=OFF
)

LOCAL_KISS_CONFIG="$WORKSPACE_ROOT/.local/kiss_matcher/lib/cmake/kiss_matcher"
if [[ -d "$LOCAL_KISS_CONFIG" ]]; then
  CMAKE_ARGS+=("-Dkiss_matcher_DIR=$LOCAL_KISS_CONFIG")
fi

LOCAL_SMALL_GICP_CONFIG="$WORKSPACE_ROOT/.local/small_gicp/lib/cmake/small_gicp"
if [[ -d "$LOCAL_SMALL_GICP_CONFIG" ]]; then
  CMAKE_ARGS+=("-Dsmall_gicp_DIR=$LOCAL_SMALL_GICP_CONFIG")
fi

colcon build --symlink-install --cmake-args "${CMAKE_ARGS[@]}"
