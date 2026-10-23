# vps-zsh-tag 🏷️

Debian / Alpine / FreeBSD 通用 Zsh 看板脚本，为你的 VPS 终端提供优雅的信息展示和现代化的 Zsh 体验。

支持系统：Debian 及其衍生版（Ubuntu、Kali、Raspbian、Pop!_OS、Deepin、Devuan 等）、Alpine Linux 与 FreeBSD。

## ✨ 功能特性

### 🎨 智能终端美化
- 自动安装并配置 Zsh Shell
- 根据操作系统自动着色（Debian/Ubuntu/Kali/Raspbian/Pop!_OS/Deepin/Devuan/Alpine 等）
- **目录/文件彩色显示**：`ls` 输出按文件类型着色，Tab 补全列表同样着色（`LS_COLORS`）
- 增强的命令补全功能（菜单式选择）
- **可选历史记录开关**：安装 Zsh 后询问是否开启，默认不开启
- 开启后保留 5000 条历史记录并跨会话共享（`~/.zsh_history`），支持上下箭头快速匹配

### 🏷️ 自定义看板系统
- **三行自定义标签**：厂商/用途、位置/归属、网络/警示
- **灵活的到期管理**：
  - 支持月付/季付/半年/年付周期
  - 自动计算到期日期和剩余天数
  - 7 天内到期红色警告
  - 永久标识模式（∞）
- **系统信息展示**：CPU 核心数、内存大小、操作系统版本

### 🔧 管理功能
- **纯 POSIX sh 安装器**：不依赖 bash，dash / BusyBox ash / FreeBSD sh 都能直接运行
- **一键安装**：完整配置 Zsh + 看板
- **安全移除**：仅移除看板，保留 Zsh 配置
- **彻底卸载**：还原默认 Shell、清除所有配置、可选移除 Zsh 包
- **自动备份**：安装前自动备份原有 `.zshrc`
- **权限安全**：禁止对 root 用户配置，自动设置 sudo 免密

## 📊 显示效果

```bash
[Debian GNU/Linux 13 (trixie)] 2C/1GB
∞ • 甲骨文 • 东京 • NTT

[Debian GNU/Linux 13 (trixie)] 2C/2GB
2026-03-07 (52d) • Bandwagon • LA • CN2

[Ubuntu 24.04.2 LTS] 4C/8GB
2025-12-15 (3d) • 公司云 • 数据库专用 • 谨慎操作！

[Raspbian GNU/Linux 12] 4C/4GB
∞ • 树莓派4B • 折腾用 • 随便玩

[Alpine Linux v3.21] 2C/2GB
2026-05-01 (18d) • 微型机 • 东京 • Alpine 也能用

[FreeBSD 15.1-RELEASE-p6] 4C/2GB
2026-11-15 (24d) • 家里云 • 东京 • FreeBSD 也能用
```

## 🚀 快速安装

**Debian / Ubuntu 等衍生版**（系统自带 sh，只需要 curl）：

```sh
sh -c "$(curl -s https://raw.githubusercontent.com/rsdgnchen/vps-zsh-tag/main/install.sh)"
```

**Alpine Linux**（不需要 bash，装个 curl 就能跑；脚本会自动安装 zsh、sudo 等）：

```sh
apk add --no-cache curl && sh -c "$(curl -s https://raw.githubusercontent.com/rsdgnchen/vps-zsh-tag/main/install.sh)"
```

**FreeBSD**（用系统自带的 fetch，不用安装任何额外软件包）：

```sh
sh -c "$(fetch -qo - https://raw.githubusercontent.com/rsdgnchen/vps-zsh-tag/main/install.sh)"
```

也可以先下载再运行：`sh install.sh`。安装器本身是纯 POSIX sh（dash / BusyBox ash / FreeBSD sh 均可），不依赖 bash。

## 📖 使用方法

### 主菜单
运行脚本后，提供四个选项：

```
===================================
    看板管理脚本
===================================
  1) 完整安装
  2) 仅安装Zsh
  3) 卸载看板
  4) 彻底卸载
===================================
```

### 选项说明

| 选项 | 功能 | 影响范围 |
|------|------|---------|
| **1) 完整安装** | 完整安装 Zsh + 看板系统 | 安装 Zsh，配置 Shell，创建看板 |
| **2) 仅安装Zsh** | 仅配置 Zsh 和 sudo 免密 | 安装 Zsh，配置 Shell，无看板交互 |
| **3) 卸载看板** | 仅删除看板文件 | 保留 Zsh 和 .zshrc 配置 |
| **4) 彻底卸载** | 还原所有更改 | 还原默认 Shell（Debian 为 bash，Alpine 为 ash，FreeBSD 为 sh），清除配置，可选移除 Zsh |

### 安装流程

**完整安装（选项 1）**：
1. 自动安装 Zsh 及插件
2. 选择是否开启历史记录（默认不开启，开启后记录 5000 条）
3. 选择目标用户（**禁止 root**，可自动创建新用户）
4. 配置 sudo 免密权限
5. 设置默认 Shell 为 Zsh
6. 输入三行自定义标签信息
7. 配置到期规则（可选永久模式）
8. 自动生成看板并应用配置

**仅安装 Zsh（选项 2）**：
1. 自动安装 Zsh 及插件
2. 选择是否开启历史记录（默认不开启）
3. 选择目标用户
4. 自动完成 sudo 免密、Shell 配置，适合快速部署

### 备份说明
- 安装前自动备份 `.zshrc` 为 `.zshrc.YYYYMMDD.bak`
- 备份文件保存在用户主目录
- 卸载时需手动删除 `.zshrc`（如不再使用 Zsh）

## 🔒 安全特性

- **禁止 root 配置**：防止误操作影响系统安全
- **权限隔离**：所有文件归属于目标用户
- **输入验证**：严格的日期和参数校验
- **sudoers 保护**：正确设置权限 0440

## 📁 生成的文件

安装后会在用户主目录生成以下文件：

| 文件 | 用途 |
|------|------|
| `~/.zshrc` | Zsh 主配置文件（含自动备份，历史记录段落按安装时选项生成） |
| `~/.zsh_history` | 历史记录文件（仅开启历史记录后由 Zsh 自动生成） |
| `~/.zprofile` | Zsh 登录配置（自动加载看板） |
| `~/.welcome.sh` | 看板脚本（展示系统信息和标签） |
| `~/.welcome.conf` | 看板配置文件（存储用户数据） |
| `/etc/sudoers.d/<用户名>` | sudo 免密配置 |

## 🛠️ 系统要求

- **操作系统**：Debian 及其衍生版（Ubuntu、Kali、Raspbian 等）、Alpine Linux 3.x、FreeBSD 13+
- **Shell 环境**：POSIX sh（dash / BusyBox ash / FreeBSD sh），无需 bash
- **权限要求**：root 或 sudo 权限运行
- **网络要求**：首次安装需下载 Zsh 等软件包

### Alpine 说明

脚本在 Alpine 上会自动做以下适配：

- 使用 `apk` 安装 `zsh`、`zsh-syntax-highlighting`、`zsh-autosuggestions`、`sudo`
- 看板日期用纯整数运算，不再需要 `coreutils` / GNU `date`；`ls` 彩色由 BusyBox 的 `--color` 提供
- 使用 BusyBox `adduser` 创建用户，并用 `chsh` → `usermod` → 直接修改 `/etc/passwd` 三级回退设置登录 Shell
- 自动安装 `sudo` 并写入 `/etc/sudoers.d/<用户名>` 免密配置；无法安装 sudo 时以 root 身份直接执行
- 卸载时把登录 Shell 还原为 `/bin/ash`（Debian 为 `/bin/bash`），并移除 zsh 相关包

### FreeBSD 说明

脚本通过 `uname -s` 识别 FreeBSD（13/14 没有 `/etc/os-release` 也能正确识别），并做以下适配：

- 使用 `pkg` 安装 `zsh`、`zsh-syntax-highlighting`、`zsh-autosuggestions`，首次运行 `pkg` 时自动接受引导提示
- 看板日期用纯整数运算，不再需要 `gdate` / `coreutils`
- 用户创建使用 `pw useradd -m`；主目录查询优先 `getent`，找不到时回退解析 `/etc/passwd`
- 先确认 `/usr/local/bin/zsh` 已登记进 `/etc/shells`（FreeBSD 的 `chsh` 会校验），再切换登录 Shell
- sudo 来自 pkg，免密配置写入 `/usr/local/etc/sudoers.d/<用户名>`（并检查 sudoers 的 `includedir` 是否生效）
- CPU/内存改用 `sysctl hw.ncpu`、`sysctl hw.physmem`（FreeBSD 没有 `/proc`）
- 主机名颜色使用 `#AB2B28`，终端支持真彩色时按 24 位色显示
- `ls` 彩色优先用 `--color=auto`（FreeBSD 15+），老版本回退到 `-G` + `LSCOLORS`
- 卸载时把登录 Shell 还原为 `/bin/sh`，并移除 zsh 相关包

## 🔄 更新日志

### 看板日期改为纯整数运算（最新版本）
- `.welcome.sh` 不再调用 `date -d` / `gdate`：改用 zsh 整数公历运算（days_from_civil + 100/400 闰年规则）计算下一次到期日和剩余天数
- 每次登录从约 14 次外部 `date` fork 降为 0 次
- Alpine / FreeBSD 不再安装 `coreutils`；月末钳位（31 号 → 2 月 28/29 → 次月 31 号）行为保持不变
- 顺手修正了夏令时“回拨日”多算 1 天的问题（美东等时区；Asia/Shanghai 不受影响）
- 用 6240 组差分用例对比旧实现：UTC / Asia/Shanghai 0 差异；America/New_York 仅 154 例跨回拨日的 +1 天差异（即被修正的 bug）

### 重构：安装器改为纯 POSIX sh
- `install.sh` 从 bash 改为 POSIX sh：去掉 `[[ ]]`、数组、`read -e`、`declare -p`、`pipefail` 等 bash 依赖，`dash` / BusyBox ash / FreeBSD sh 都能直接运行
- 安装时不再需要安装 bash：Debian 直接 `sh -c "$(curl ...)"`，Alpine 只需要 curl，FreeBSD 用系统自带 `fetch` 即可
- `.welcome.conf` 改为普通 `KEY='value'` 赋值（单引号转义），由 zsh source，语义不变
- 交互提示改用 `printf` + `read -r`（失去 bash 的行编辑，其他交互不变）
- 已在 Debian 13、Alpine 3.21、FreeBSD 15.1 上验证安装与卸载

### FreeBSD 支持
- 新增 FreeBSD 支持：用 `uname -s` 识别系统，`pkg` 负责安装/卸载，首次运行自动接受 pkg 引导
- 用户创建改用 `pw useradd -m`；`chsh` 前自动把 `/usr/local/bin/zsh` 登记进 `/etc/shells`
- 免密配置写入 `/usr/local/etc/sudoers.d/`，并校验 sudoers 的 `includedir`
- CPU/内存改用 `sysctl`；插件路径补上 `/usr/local/share/`
- 主机名提示符使用 `#AB2B28`；`ls` 彩色兼容 BSD `-G`/`LSCOLORS`
- 彻底卸载时登录 Shell 还原为 `/bin/sh`

### Alpine Linux 支持
- 新增 Alpine Linux 支持：自动识别 `/etc/alpine-release`，使用 `apk` 完成安装与卸载
- 包管理、用户创建（BusyBox `adduser`）、主目录查询（无 `getent` 时回退 awk）、登录 Shell 切换（无 `chsh` 时回退 `usermod` / `/etc/passwd`）均按发行版适配
- Alpine 的 BusyBox `ls` 支持 `--color`，`ls` 彩色别名正常生效
- `.zshrc` 同时兼容 Debian 与 Alpine 的 zsh 插件路径；`ls --color` 不可用时自动跳过彩色别名
- Alpine 彻底卸载时移除 zsh 相关包，并将登录 Shell 还原为 `/bin/ash`

### 修复: zsh 目录不显示颜色
- 生成的 `.zshrc` 新增 `LS_COLORS` 与 `ls --color=auto` 系列别名（`ls`/`ll`/`la`/`l`），目录及文件按类型着色
- Tab 补全列表同步着色（`zstyle ':completion:*' list-colors`）

### 历史记录开关
- 安装 Zsh 后新增"是否开启历史记录"选项，**默认不开启**
- 开启后保留 5000 条历史（`HISTSIZE`/`SAVEHIST`）并跨会话共享，自动写入 `~/.zsh_history`
- 未开启时生成的 `.zshrc` 显式关闭历史（`HISTSIZE=0`），不保存任何记录

### 重大重构
- 精简菜单式交互界面
- 新增"移除看板"独立选项
- 增强"彻底卸载"功能（可选移除 Zsh）
- 优化代码结构，使用函数模块化
- 改进输入验证和错误处理
- 增强安全限制（禁止 root 操作）

## 📝 许可

MIT License