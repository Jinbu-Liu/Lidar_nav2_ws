# Lidar_nav2_ws 安装部署记录

- 执行日期：2026-07-20
- 工作空间：`/home/jaka/nav_ws/Lidar_nav2_ws`
- 执行依据：项目根目录 `README.md`
- 当前结论：**依赖已准备，33 个 ROS 2 包全量构建成功；仿真、点云转换、FAST-LIO 参数和 KISS-Matcher 重定位完成冒烟验证。**

> 本记录描述的是当前机器上的实际部署结果。实机 LiDAR、底盘和完整 GUI 导航闭环需要连接对应硬件后继续验证。

## 1. 环境信息

| 项目 | 实际环境 |
|---|---|
| 操作系统 | Ubuntu 22.04.5 LTS，x86_64 |
| ROS 2 | Humble（`/opt/ros/humble`） |
| Gazebo | Gazebo Classic 11.10.2 |
| CMake | 3.22.1 |
| GCC | 11.4.0 |
| 工作空间包数量 | `colcon list` 识别 33 个包 |
| 构建方式 | `colcon build --symlink-install`，Release，CUDA 关闭 |

README 原先写的是 Gazebo Fortress，但项目的 launch、插件和已安装程序实际使用 `gazebo_ros` + Gazebo Classic 11，README 已同步修正。

## 2. 当前安装方式

本机没有可用的非交互 `sudo` 密码，系统级 `apt install` 未执行成功，也没有修改 `/usr/local`。缺失依赖采用工作空间内的无 root 安装：

| 依赖 | 当前安装位置 | 版本/说明 |
|---|---|---|
| `gazebo_plugins` | `.local/ros_deps/opt/ros/humble` | Debian 包 `3.9.0-1jammy.20260606.075130` |
| `pointcloud_to_laserscan` | `.local/ros_deps/opt/ros/humble` | Debian 包 `2.0.1-3jammy.20260605.164325` |
| KISS-Matcher | `.local/kiss_matcher` | 当前子模块源码，使用 `-fPIC` 重新编译 |
| small_gicp | `.local/small_gicp` | 源码提交 `57c1106daf83c2c79ee0c58a9c7ed0032298ff4e`，共享库 + PIC |

`.local/` 已加入 `.gitignore`，由 `scripts/setup_env.sh` 统一加载。启动脚本和构建脚本均会加载该环境。

如果有 sudo 权限，ROS 二进制依赖建议改为系统安装：

```bash
sudo apt-get update
sudo apt-get install -y \
  ros-humble-gazebo-plugins \
  ros-humble-pointcloud-to-laserscan
```

## 3. 实际构建流程

当前机器可直接执行：

```bash
cd /home/jaka/nav_ws/Lidar_nav2_ws
source scripts/setup_env.sh
./scripts/build.sh
source install/setup.bash
```

`scripts/build.sh` 当前使用：

```bash
colcon build --symlink-install --cmake-args \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_CUDA=OFF
```

当工作空间内存在本地 KISS-Matcher/small_gicp 时，脚本还会传入它们的 CMake 配置目录，确保不会误用 `/usr/local` 中不可链接的旧库。

全量构建结果：

```text
Summary: 33 packages finished [3min 11s]
```

对应完整构建日志目录：`log/build_2026-07-20_17-10-25/`。后续修改 launch 文件后又完成了相关包的增量构建。

## 4. 遇到的问题与处理记录

| # | 问题/现象 | 原因 | 处理 | 状态 |
|---|---|---|---|---|
| 1 | 缺少 `gazebo_plugins` 和 `pointcloud_to_laserscan` | 原 package.xml 未完整声明运行依赖，本机也未安装对应 ROS 包 | 补充 package.xml；将两个 Debian 包解压到 `.local/ros_deps` 并由 `setup_env.sh` 加载 | 已解决 |
| 2 | `sudo apt-get install` 无法继续 | 当前会话不能交互输入 sudo 密码 | 未修改系统；改用工作空间内无 root 安装 | 已解决（本机方案） |
| 3 | `global_relocalization` 配置阶段报不存在的 `launch/` 目录 | `CMakeLists.txt` 要求安装一个实际不存在的目录 | 删除无效的 `INSTALL_TO_SHARE launch` | 已解决 |
| 4 | `global_relocalization_kiss_matcher` 链接失败，出现 `R_X86_64_PC32` / “recompile with -fPIC” | `/usr/local/lib/libkiss_matcher_core.a` 未使用 PIC 编译，不能链接到 ROS 共享库 | 以 `CMAKE_POSITION_INDEPENDENT_CODE=ON` 在 `.local/kiss_matcher` 重新构建安装，并让 CMake 优先使用它 | 已解决 |
| 5 | small_gicp CMake 配置缺少 `small_gicp-targets.cmake` | 之前 FetchContent 生成/安装的配置不完整 | 将 small_gicp 以共享库、PIC 方式安装到 `.local/small_gicp`；包内优先 `find_package`，找不到才 FetchContent | 已解决 |
| 6 | small_gicp 链接目标名不一致 | 外部安装导出 `small_gicp::small_gicp`，部分项目引用 `small_gicp` | 在四个相关 CMakeLists 中增加兼容 alias | 已解决 |
| 7 | 多个脚本和重定位 launch 写死 `/home/pio/Nav2_3D_ws` | 原代码依赖作者机器目录 | Shell 使用动态 `WORKSPACE_ROOT`；Python/C++ 使用 ament package share 查找地图和 PCD | 已解决 |
| 8 | 仿真/实机时间源混用，实机点云转换仍固定使用仿真时间 | 多个 launch 把 `use_sim_time` 写死为 `true` 或 `false` | 为 LIO 接口、点云处理、重定位和 Nav2 增加 launch 参数；仿真脚本统一传 `true`，实机脚本统一传 `false` | 已解决 |
| 9 | FAST-LIO 实机脚本沿用仿真 `lidar_type=5` | `mid360.yaml` 同时被仿真和实机复用 | launch 增加整数参数；仿真传 `5`，MID-360 实机传 `4` | 已解决 |
| 10 | Gazebo 首次启动时 `spawn_entity` 超时 | 世界和 Gazebo 服务尚未就绪就立即生成机器人 | 延迟 5 秒执行生成节点，并将生成超时调到 60 秒 | 已解决 |
| 11 | 仿真建图同时启动 SLAM Toolbox 和静态 `map_server` | 两个节点都会发布 `/map`，可能互相覆盖 | Nav2 launch 增加 `launch_map_server`；建图传 `false`，导航传 `true` | 已解决 |
| 12 | ROS 包运行依赖未在清单中声明 | package.xml 只覆盖了部分编译依赖 | 为 bringup、URDF、GUI 和重定位包补充 `exec_depend`/`depend` | 已解决 |
| 13 | `rosdep check` 报 `click_loc` 的未知 key `ament_python` | KISS-Matcher 内嵌第三方测试包的 rosdep key 无定义，不属于当前导航构建目标 | 保留上游内容，不改动用户子模块；该错误不影响 33 个工作空间包构建 | 非阻塞 |
| 14 | `rosdep check` 仍称两个 ROS 二进制包未安装 | 当前采用 `.deb` 解压而非 dpkg 注册，rosdep 只识别系统包数据库 | 实际包已能被 ROS 找到；有 sudo 后改用 apt 安装即可消除提示 | 非阻塞 |
| 15 | 沙箱中 ROS 日志目录及 DDS 网络受限 | 测试环境不能写默认 `~/.ros/log`，且限制 UDP socket | 测试时设置 `ROS_LOG_DIR=/tmp/lidar_nav_ros_logs`；需要 DDS 的验证按授权在沙箱外运行 | 测试环境限制 |
| 16 | RTAB-Map 构建出现可选功能警告 | 缺少可选的 ArUco 接口、pcap/png 等能力 | 核心包仍成功构建；当前 LiDAR/Nav2 流程不依赖这些可选功能 | 非阻塞 |
| 17 | GUI 遥控持续报 `rounded_rect() got an unexpected keyword argument 'tags'`，按键无法控制 | 圆角绘制函数未转发 Canvas 的 `tags` 参数；ROS 定时器还从后台线程读取 Tk 变量 | 允许绘制函数转发关键字参数；将 20 Hz 速度发布移到 Tk 主线程；增强全局按键绑定、焦点丢失停车、空格防重复和 SIGINT 退出 | 已解决 |
| 18 | 2D/PCD 地图使用固定文件名，PCD 还需手动移动 | 保存脚本没有生成时间戳；FAST-LIO 保存服务只使用启动时读取的固定路径 | 两类地图改用 `YYYYMMDD_HHMMSS`；PCD 脚本动态设置 `map_file_path` 并直接写入 `src/me_nav2_bringup/pcd/`；增加写盘校验、重名保护和空点云保护 | 已解决 |
| 19 | 多窗口启动后缺少统一关闭入口 | 各 launch 分散在多个终端，手动逐个关闭不便 | 新增 `scripts/stop_all.sh`，先 TERM、等待 2 秒后 KILL 残留，并停止 ROS daemon；支持 `--dry-run` | 已解决 |

## 5. 主要代码与配置调整

- 新增 `scripts/setup_env.sh`，加载 ROS 2 和工作空间内本地依赖。
- 构建脚本保留原有 `BUILD_CUDA=OFF`，并选择本地 PIC 版 KISS-Matcher/small_gicp。
- 修复四类重定位包的 CMake 目标兼容和依赖发现顺序。
- 将地图/PCD/SLAM 配置路径改为可迁移路径。
- 为仿真和实机入口明确传递 `use_sim_time` 与 FAST-LIO `lidar_type`。
- 避免建图时静态地图服务器与 SLAM Toolbox 同时发布 `/map`。
- 修复 Gazebo 机器人生成时序。
- 补齐 package.xml 运行依赖。
- 修正中英文 README 中的 Gazebo 类型、包数量、默认重定位方案、时间源和 PCD 路径说明。

## 6. 验证结果

### 6.1 静态与构建验证

- 所有修改过的 Python launch 文件通过 `python3 -m py_compile`。
- 所有入口 Shell 脚本通过 `bash -n`。
- `git diff --check` 通过。
- README 构建入口全量完成：33 个包成功。
- 受影响的 7 个包增量构建成功，随后 `me_nav2_bringup` 再次增量构建成功。
- KISS-Matcher 重定位共享库执行 `ldd` 未发现缺失库。

### 6.2 ROS 启动参数解析

以下 launch 均通过 `ros2 launch ... --show-args`：

- FAST-LIO、Point-LIO
- 三个 `lio_interface` 启动文件
- `sensor_scan_generation`
- `pointcloud_to_laserscan`
- Nav2 bringup（含 `launch_map_server`）
- KISS-Matcher + small_gicp 重定位
- 纯 small_gicp 重定位

### 6.3 冒烟测试

- Gazebo Classic、RViz 和 `robot_state_publisher` 能启动。
- 延时修复后日志出现：`SpawnEntity: Successfully spawned entity [simple_car]`。
- Gazebo skid-steer 插件加载成功并订阅 `/cmd_vel`。
- `pointcloud_to_laserscan_node` 启动后可正常接收中断并退出。
- KISS-Matcher 重定位节点成功加载先验地图：`174092 points`；无实时扫描时仅提示没有累计点云，符合预期。
- FAST-LIO 实际启动日志确认：实机参数为 `p_pre->lidar_type 4`，仿真参数为 `p_pre->lidar_type 5`。
- GUI 遥控实际启动 5 秒无 Tkinter 回调异常；消息级测试确认 W 发布正向线速度、Shift+A 发布加倍角速度、急停发布全零速度。
- 地图脚本路径模拟确认 2D 地图输出为 `map/YYYYMMDD_HHMMSS.{yaml,pgm}`，PCD 输出为 `pcd/YYYYMMDD_HHMMSS.pcd`；FAST-LIO 运行测试确认动态路径生效，空点云时安全返回失败且节点不崩溃。
- 所有冒烟测试结束后，未残留 `gzserver`、`gzclient`、FAST-LIO、KISS-Matcher 或静态 TF 测试进程。

短时测试由 `timeout` 主动结束，因此出现 `124`/`137` 的测试退出码不代表节点启动失败；判断依据是超时前的节点日志和后续残留进程检查。

## 7. 运行方式

项目入口脚本会自动加载本地依赖。建议从项目根目录执行：

```bash
cd /home/jaka/nav_ws/Lidar_nav2_ws

# 仿真建图
./scripts/mapping_sim.sh

# 仿真导航
./scripts/nav2_sim.sh

# 实机建图
./scripts/mapping_real.sh

# 实机导航
./scripts/nav2_real.sh
```

手动执行 ROS 命令时先加载：

```bash
source scripts/setup_env.sh
source install/setup.bash
```

当前导航脚本默认启用 KISS-Matcher + small_gicp。若切换为纯 small_gicp，必须先注释 KISS-Matcher 启动段，保证同一时间只有一个节点发布 `map -> odom`。

## 8. 尚未完成或需要现场确认的内容

1. **实机硬件未验证**：没有连接 MID-360、IMU 和底盘，无法确认 IP、数据频率、外参及真实定位精度。
2. **底盘驱动不在当前启动链中**：实机 Nav2 会发布 `/cmd_vel`，但需要现场底盘驱动订阅并执行该速度指令。
3. **完整长时间闭环未运行**：已验证关键组件启动和资源加载，但没有保持所有 GUI 窗口进行长时间建图/导航。
4. **地图数据需要匹配现场**：`nav_test_4_27.yaml` 和 `nav_test_4_27.pcd` 是现有先验数据，换环境后必须重新建图并更新两处地图。
5. **控制话题需要避免争用**：GUI 遥控和 Nav2 都可能发布 `/cmd_vel`，不要在 Nav2 正在控制时同时发送 GUI 速度指令。
6. **无 root 安装是机器局部状态**：复制或重新克隆仓库时 `.local/` 不会随 Git 带走，应优先使用 apt 安装 ROS 二进制依赖，并重新构建 PIC 版 KISS-Matcher/small_gicp。

## 9. 原有工作区状态说明

开始部署前工作区已经存在用户修改：

- `scripts/build.sh` 已包含 `-DBUILD_CUDA=OFF`；本次保留并在其上扩展。
- KISS-Matcher 子模块当前为提交 `669fe866b1c612daa3702292571c25dc1bc61c86`，与父仓库记录的 `e3440b63340af7414ebd0fdde04e40f02ff4e7d2` 不同。
- 子模块中已有未跟踪文件 `ros/COLCON_IGNORE`。

这些原有修改没有被回退或覆盖。为修复旧 CMake 缓存，原生成目录被可恢复地移动到 `/tmp/lidar-nav-relocalization-backup.Bc5kV6/`；该路径属于临时目录，不应作为长期备份。
