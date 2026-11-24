# vps-zsh-tag 🏷️

Debian / Arch / Fedora / openSUSE / Void / Alpine / FreeBSD 通用 Zsh 看板脚本，为你的 VPS 终端提供优雅的信息展示和现代化的 Zsh 体验。

支持系统：Debian 及其衍生版（Ubuntu、Kali、Raspbian、Pop!_OS、Deepin、Devuan、Linux Mint 等）、Arch 及其衍生版（Manjaro、EndeavourOS、CachyOS、Garuda、Arch Linux ARM）、Fedora / RHEL 系（RHEL、CentOS Stream、Rocky Linux、AlmaLinux、Oracle Linux、Amazon Linux）、openSUSE（Leap / Tumbleweed / SLES）、Void Linux、Alpine Linux 与 FreeBSD。

## ✨ 功能特性

### 🎨 智能终端美化
- 自动安装并配置 Zsh Shell
- 根据操作系统自动着色（Debian/Ubuntu/Kali、Arch/Manjaro、Fedora/RHEL、openSUSE、Void、Alpine、FreeBSD 等）
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
- **自动备份**：安装前自动备份原有 `.zshrc`（以及用户自定义的 `.zprofile`）
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

[Arch Linux] 2C/2GB
∞ • 家里云 • 东京 • pacman 也能用

[Fedora Linux 43] 4C/4GB
2026-06-01 (12d) • 公司云 • 法兰克福 • dnf 也能用

[openSUSE Tumbleweed] 4C/8GB
∞ • 测试机 • 本地 • zypper 也能用

[Void Linux] 2C/1GB
2026-12-01 (7d) • 小机 • 东京 • xbps 也能用

[FreeBSD 15.1-RELEASE-p6] 4C/2GB
2026-11-15 (24d) • 家里云 • 东京 • FreeBSD 也能用
```

## 🚀 快速安装

脚本会根据 `/etc/os-release`（或包管理器）自动识别发行版，调用对应的包管理器安装 Zsh 和插件。

**Debian / Ubuntu 等衍生版**（系统自带 sh，只需要 curl）：

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/rsdgnchen/vps-zsh-tag/main/install.sh)"
```

**Arch Linux / Manjaro / EndeavourOS / Arch Linux ARM**（自带 curl 与 pacman）：

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/rsdgnchen/vps-zsh-tag/main/install.sh)"
```

**Fedora / RHEL / CentOS Stream / Rocky / AlmaLinux / Amazon Linux**（自带 curl 与 dnf/yum）：

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/rsdgnchen/vps-zsh-tag/main/install.sh)"
```

> RHEL / Rocky / AlmaLinux 如需 zsh 语法高亮与自动建议，需先启用 EPEL 源（详见下方「Fedora / RHEL 系说明」）。

**openSUSE Leap / Tumbleweed**（自带 curl 与 zypper）：

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/rsdgnchen/vps-zsh-tag/main/install.sh)"
```

**Void Linux**（需要 curl，可用 xbps 安装）：

```sh
xbps-install -Sy curl && sh -c "$(curl -fsSL https://raw.githubusercontent.com/rsdgnchen/vps-zsh-tag/main/install.sh)"
```

**Alpine Linux**（不需要 bash，装个 curl 就能跑；脚本会自动安装 zsh、sudo 等）：

```sh
apk add --no-cache curl && sh -c "$(curl -fsSL https://raw.githubusercontent.com/rsdgnchen/vps-zsh-tag/main/install.sh)"
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
| **4) 彻底卸载** | 还原所有更改 | 还原默认 Shell（Debian / Arch / Fedora / openSUSE / Void 为 bash，Alpine 为 ash，FreeBSD 为 sh），清除配置，可选移除 Zsh |

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
- 若用户已有自定义 `.zprofile`，先备份为 `.zprofile.YYYYMMDD.bak`；卸载看板/彻底卸载时自动还原
- 备份文件保存在用户主目录
- 卸载时需手动删除 `.zshrc`（如不再使用 Zsh）

### 看板加载时机
看板由 `~/.zprofile` 在登录 Shell 时加载（SSH 登录、`su - <用户>` 等）；在同一会话中新开的非登录终端不会重复显示。

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
| `~/.zprofile` | Zsh 登录配置（自动加载看板；原有文件会备份，卸载时还原） |
| `~/.welcome.sh` | 看板脚本（展示系统信息和标签） |
| `~/.welcome.conf` | 看板配置文件（存储用户数据） |
| `/etc/sudoers.d/<用户名>` | sudo 免密配置（FreeBSD 为 `/usr/local/etc/sudoers.d/<用户名>`） |

## 🛠️ 系统要求

- **操作系统**：Debian 系、Arch 系、Fedora/RHEL 系、openSUSE、Void Linux、Alpine Linux 3.x、FreeBSD 13+
- **Shell 环境**：POSIX sh（dash / BusyBox ash / FreeBSD sh），无需 bash
- **权限要求**：root 或 sudo 权限运行
- **网络要求**：首次安装需下载 Zsh 等软件包

### Alpine 说明

脚本在 Alpine 上会自动做以下适配：

- 使用 `apk` 安装 `zsh`、`zsh-syntax-highlighting`、`zsh-autosuggestions`、`sudo`
- 看板日期用纯整数运算，不再需要 `coreutils` / GNU `date`；`ls` 彩色由 BusyBox 的 `--color` 提供
- 使用 BusyBox `adduser` 创建用户，并用 `chsh` → `usermod` → 直接修改 `/etc/passwd` 三级回退设置登录 Shell
- 自动安装 `sudo` 并写入 `/etc/sudoers.d/<用户名>` 免密配置；无法安装 sudo 时以 root 身份直接执行
- 卸载时把登录 Shell 还原为 `/bin/ash`（其他 Linux 发行版为 `/bin/bash`，FreeBSD 为 `/bin/sh`），并移除 zsh 相关包

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

### Arch Linux 说明

- 通过 `/etc/os-release` 的 `ID=arch` / `ID_LIKE=arch` 识别（覆盖 Manjaro、EndeavourOS、CachyOS、Garuda、Arch Linux ARM），使用 `pacman` 安装与卸载
- 安装 `zsh`、`zsh-syntax-highlighting`、`zsh-autosuggestions`、`sudo`；插件路径为 `/usr/share/zsh/plugins/...`
- pacman 7 的下载沙盒在部分 LXC / 容器环境中不可用，脚本会自动检测并改用 `--disable-sandbox` 重试
- 用户创建使用 `useradd -m`；`chsh` 前自动把 zsh 路径登记进 `/etc/shells`
- 卸载时把登录 Shell 还原为 `/bin/bash`，并移除已安装的 zsh 相关包

### Fedora / RHEL 系说明

- 通过 `ID` / `ID_LIKE` 识别 Fedora、RHEL、CentOS Stream、Rocky Linux、AlmaLinux、Oracle Linux、Amazon Linux，优先使用 `dnf`，只有 `yum` 的系统自动回退
- 安装 `zsh`、`zsh-syntax-highlighting`、`zsh-autosuggestions`、`sudo`
- RHEL / Rocky / AlmaLinux 的 zsh 插件包通常来自 EPEL：未启用 EPEL 时插件会安装失败并给出警告，Zsh 与看板仍可正常使用
- 卸载时把登录 Shell 还原为 `/bin/bash`，并移除已安装的 zsh 相关包

### openSUSE 说明

- 通过 `ID` / `ID_LIKE` 识别 openSUSE Leap / Tumbleweed / SLES，使用 `zypper` 安装与卸载
- `zypper` 刷新/安装时自动导入 GPG 密钥（`--gpg-auto-import-keys`），适合非交互环境
- 安装 `zsh` 与 `sudo`；插件路径兼容 `/usr/share/zsh/plugins/...`
- openSUSE 官方 OSS 源未收录 `zsh-syntax-highlighting` / `zsh-autosuggestions`（`shells` 源也只有 zsh 本体），脚本会跳过插件并给出警告；Zsh 与看板仍可正常使用，需要高亮/自动建议时可从上游项目手动安装
- 卸载时把登录 Shell 还原为 `/bin/bash`，并移除已安装的 zsh 相关包

### Void Linux 说明

- 通过 `ID=void` 识别，使用 `xbps-install` / `xbps-remove` 安装与卸载
- 安装 `zsh`、`zsh-syntax-highlighting`、`zsh-autosuggestions`、`sudo`
- 卸载时把登录 Shell 还原为 `/bin/bash`（不存在时回退 `/bin/sh`），并移除已安装的 zsh 相关包

### 其他发行版识别方式

- 优先读取 `/etc/os-release` 的 `ID` 与 `ID_LIKE`，因此 Ubuntu、Linux Mint、Kali 等 Debian 衍生版会自动走 Debian 分支；Manjaro、EndeavourOS 自动走 Arch 分支；Rocky、AlmaLinux 自动走 Fedora/RHEL 分支
- `/etc/os-release` 缺失或无法识别时，按 `/etc/alpine-release`、`/etc/debian_version` 以及 `pacman`、`dnf`/`yum`、`zypper`、`xbps-install`、`apk`、`apt-get` 是否存在兜底
- 已有用户的主组不是同名组（如 openSUSE 的 `users`）时，脚本用 `id -gn` 取主组，不会因为 `chown user:user` 失败而中断

## 🔄 更新日志

### 新增 Arch / Fedora / RHEL / openSUSE / Void 支持（最新版本）
- 发行版识别改为读取 `/etc/os-release` 的 `ID` / `ID_LIKE`，再按发行版标志文件与包管理器兜底；覆盖 Arch 系（含 Manjaro、EndeavourOS、CachyOS、Garuda、Arch Linux ARM）、Fedora/RHEL 系（含 CentOS Stream、Rocky、Alma、Oracle Linux、Amazon Linux）、openSUSE Leap/Tumbleweed/SLES、Void Linux
- 新增 `pacman` / `dnf`（`yum` 回退）/ `zypper` / `xbps` 包管理分支，安装、刷新、卸载、已安装检测均已适配
- pacman 7 的下载沙盒在 LXC/容器中不可用时，自动改用 `--disable-sandbox` 重试
- `zypper` 使用 `--gpg-auto-import-keys`，非交互环境也能刷新仓库
- `chown` 改用用户主组（`id -gn`），兼容 openSUSE 等主组不是同名组的已有用户；sudoers 检查兼容 openSUSE 的 `/usr/etc/sudoers`
- CPU/内存探测不再依赖 `awk`（openSUSE 最小镜像可能没有），改用 `grep` 与 shell 内建 `read`
- 提示符配色新增 Arch / Manjaro / Fedora / RHEL / Rocky / openSUSE / Void 等
- Void 的 xbps 过旧、无法解析新仓库元数据时，自动升级 xbps 并重新同步后重试
- 卸载时只移除真正安装过的 zsh 相关包，避免某个插件缺失导致整条移除命令失败
- 已在 Debian 13、Alpine 3.21、Arch Linux ARM、Fedora 45、Rocky Linux 9.9、openSUSE Tumbleweed / Leap 16.1、Void Linux（aarch64）上验证安装与卸载

### 修复安装/卸载的若干问题
- 修复无 sudo 且安装 sudo 失败时，后续步骤仍调用 `sudo` 导致脚本直接退出的问题（现在会继续以 root 执行）
- `.zprofile` 不再对交互式登录 Shell 重复 source `.zshrc`，避免 `compinit`、别名等执行两次
- 不再对用户整个家目录执行 `chown -R`，只修正脚本生成的文件
- 安装前备份用户原有的 `.zprofile`；卸载看板/彻底卸载时自动还原，非本脚本生成的 `.zprofile` 不再被误删
- CPU/内存探测增加容错：`/proc` 或 `sysctl` 不可用时不再报算术错误，CPU 至少显示 1 核
- 永久模式且三行标签全空时不再多输出一行空行，标签行去掉多余的尾随空格
- 标准输入被关闭（如 `sh install.sh < /dev/null`）时给出明确错误提示
- 已在 Debian 13、Alpine 3.21 容器中完整验证安装（含看板输出）与卸载（含 `.zprofile` 还原）

### 看板日期改为纯整数运算
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
- 包管理、用户创建（BusyBox `adduser`）、主目录查询（无 `getent` 时回退解析 `/etc/passwd`）、登录 Shell 切换（无 `chsh` 时回退 `usermod` / `/etc/passwd`）均按发行版适配
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