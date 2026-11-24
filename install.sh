#!/bin/sh
# ==========================================================
# 脚本名称: Debian / Arch / Fedora / openSUSE / Void / Alpine / FreeBSD 通用 Zsh 看板脚本
# 支持系统: Debian 系、Arch 系、Fedora/RHEL 系、openSUSE 系、Void Linux、Alpine Linux、FreeBSD
# 依赖说明: 仅需 POSIX sh（dash / BusyBox ash / FreeBSD sh），无需 bash
# ==========================================================

set -eu

# ---------- 输出与输入 ----------
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_RESET='\033[0m'

say()  { printf '%b\n' "$*"; }
warn() { printf '%b\n' "${C_YELLOW}$*${C_RESET}"; }
fail() { printf '%b\n' "${C_RED}$*${C_RESET}"; }

# 交互读取（POSIX sh 的 read 没有 -p / -e，提示符单独写到 stderr）
# stdin 被关闭（如 install.sh < /dev/null）时给出明确提示，而不是被 set -e 静默终止
ask() {
    printf '%s' "$1" >&2
    if ! read -r "$2"; then
        printf '\n' >&2
        fail "错误: 读取输入失败（标准输入已关闭），已退出。"
        exit 1
    fi
}

# 截断到 120 个字符：zsh 此时已安装，用它保证多字节字符不会被截断
clip() {
    if command -v zsh >/dev/null 2>&1; then
        zsh -fc 'print -rn -- "${1[1,120]}"' _ "$1"
    else
        printf '%.120s' "$1"
    fi
}

# 把值转义成可安全放进单引号的字符串（供 .welcome.conf 被 zsh source）
sq() {
    _s=$1
    _o=
    _q="'"
    while :; do
        case $_s in
            *"$_q"*)
                _o="$_o${_s%%"$_q"*}'\\''"
                _s=${_s#*"$_q"}
                ;;
            *) _o="$_o$_s"; break ;;
        esac
    done
    printf '%s' "$_o"
}

# ---------- 发行版检测 ----------
# 支持: Debian 系、Arch 系、Fedora/RHEL 系、openSUSE 系、Void Linux、Alpine Linux、FreeBSD
# 优先读 /etc/os-release 的 ID / ID_LIKE（覆盖各种衍生版），再按包管理器兜底
OS_ID=""
OS_LIKE=""
if [ -r /etc/os-release ]; then
    OS_ID=$( . /etc/os-release 2>/dev/null; printf '%s' "${ID:-}" ) || true
    OS_LIKE=$( . /etc/os-release 2>/dev/null; printf '%s' "${ID_LIKE:-}" ) || true
fi

DISTRO_FAMILY=""
if [ "$(uname -s)" = "FreeBSD" ]; then
    DISTRO_FAMILY="freebsd"
elif [ -n "$OS_ID$OS_LIKE" ]; then
    case " $OS_ID $OS_LIKE " in
        *" alpine "*) DISTRO_FAMILY="alpine" ;;
        *" arch "*|*" manjaro "*|*" endeavouros "*|*" cachyos "*|*" garuda "*)
            DISTRO_FAMILY="arch" ;;
        *" debian "*|*" ubuntu "*|*" linuxmint "*|*" kali "*|*" raspbian "*|*" pop "*|*" deepin "*|*" devuan "*)
            DISTRO_FAMILY="debian" ;;
        *" fedora "*|*" rhel "*|*" centos "*|*" rocky "*|*" almalinux "*|*" ol "*|*" amzn "*|*" oracle "*)
            DISTRO_FAMILY="fedora" ;;
        *" opensuse "*|*" suse "*|*" sled "*|*" sles "*)
            DISTRO_FAMILY="suse" ;;
        *" void "*) DISTRO_FAMILY="void" ;;
    esac
fi

# /etc/os-release 缺失或未识别时，按发行版标志文件 / 包管理器兜底
if [ -z "$DISTRO_FAMILY" ]; then
    if [ -f /etc/alpine-release ] || command -v apk >/dev/null 2>&1; then
        DISTRO_FAMILY="alpine"
    elif [ -f /etc/debian_version ] || command -v apt-get >/dev/null 2>&1; then
        DISTRO_FAMILY="debian"
    elif command -v pacman >/dev/null 2>&1; then
        DISTRO_FAMILY="arch"
    elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
        DISTRO_FAMILY="fedora"
    elif command -v zypper >/dev/null 2>&1; then
        DISTRO_FAMILY="suse"
    elif command -v xbps-install >/dev/null 2>&1; then
        DISTRO_FAMILY="void"
    fi
fi

if [ -z "$DISTRO_FAMILY" ]; then
    fail "错误: 无法识别系统。仅支持 Debian 系、Arch 系、Fedora/RHEL 系、openSUSE、Void Linux、Alpine Linux、FreeBSD。"
    exit 1
fi

# sudoers 目录：FreeBSD 的 sudo 来自 pkg，配置在 /usr/local/etc 下
case "$DISTRO_FAMILY" in
    freebsd) SUDOERS_DIR="/usr/local/etc/sudoers.d" ;;
    *)       SUDOERS_DIR="/etc/sudoers.d" ;;
esac

# Fedora/RHEL 系的新旧包管理器（CentOS 7 等只有 yum）
RPM_PKG=""
if [ "$DISTRO_FAMILY" = "fedora" ]; then
    if command -v dnf >/dev/null 2>&1; then
        RPM_PKG="dnf"
    else
        RPM_PKG="yum"
    fi
fi

# pacman 7 的下载沙盒在部分容器 / LXC 中不可用，检测到失败时自动改用 --disable-sandbox
PACMAN_SANDBOX=""

# ---------- 包管理器封装 ----------
pkg_update() {
    case "$DISTRO_FAMILY" in
        alpine)  sudo apk update ;;
        debian)  sudo apt update ;;
        arch)
            if [ -n "$PACMAN_SANDBOX" ]; then
                sudo pacman -Sy --noconfirm $PACMAN_SANDBOX
            elif ! _pkg_out=$(sudo pacman -Sy --noconfirm 2>&1); then
                warn "提示: 当前环境不支持 pacman 沙盒（常见于 LXC/容器），改用 --disable-sandbox 重试。"
                if sudo pacman -Sy --noconfirm --disable-sandbox; then
                    PACMAN_SANDBOX="--disable-sandbox"
                else
                    printf '%s\n' "$_pkg_out" >&2
                    return 1
                fi
            fi ;;
        fedora)  sudo "$RPM_PKG" -y makecache ;;
        suse)    sudo zypper --non-interactive --gpg-auto-import-keys refresh ;;
        void)
            if ! sudo xbps-install -S; then
                # 老旧系统/镜像的 xbps 可能无法解析新的仓库元数据，先自我升级再重试
                warn "提示: xbps 版本过旧，正在升级 xbps 后重试..."
                sudo xbps-install -S -u -y xbps || return 1
                sudo xbps-install -S || return 1
            fi ;;
        freebsd) sudo env ASSUME_ALWAYS_YES=yes pkg update ;;
    esac
}

pkg_install() {
    case "$DISTRO_FAMILY" in
        alpine)  sudo apk add "$@" ;;
        debian)  sudo apt install -y "$@" ;;
        # $PACMAN_SANDBOX 故意不加引号：为空时不传参数，非空时传 --disable-sandbox
        arch)    sudo pacman -S --needed --noconfirm $PACMAN_SANDBOX "$@" ;;
        fedora)  sudo "$RPM_PKG" install -y "$@" ;;
        suse)    sudo zypper --non-interactive --gpg-auto-import-keys install "$@" ;;
        void)    sudo xbps-install -y "$@" ;;
        freebsd) sudo env ASSUME_ALWAYS_YES=yes pkg install -y "$@" ;;
    esac
}

pkg_purge() {
    case "$DISTRO_FAMILY" in
        alpine)  sudo apk del "$@" ;;
        debian)  sudo apt remove --purge -y "$@" && sudo apt autoremove --purge -y ;;
        arch)    sudo pacman -Rns --noconfirm "$@" ;;
        fedora)  sudo "$RPM_PKG" remove -y "$@" && sudo "$RPM_PKG" autoremove -y ;;
        suse)    sudo zypper --non-interactive remove --clean-deps "$@" ;;
        void)    sudo xbps-remove -Ry "$@" ;;
        freebsd) sudo env ASSUME_ALWAYS_YES=yes pkg delete -y "$@" \
            && sudo env ASSUME_ALWAYS_YES=yes pkg autoremove -y ;;
    esac
}

# 判断软件包是否已安装（卸载时只移除真正存在的包）
pkg_installed() {
    case "$DISTRO_FAMILY" in
        alpine)      apk info -e "$1" >/dev/null 2>&1 ;;
        debian)      dpkg -s "$1" >/dev/null 2>&1 ;;
        arch)        pacman -Q "$1" >/dev/null 2>&1 ;;
        fedora|suse) rpm -q "$1" >/dev/null 2>&1 ;;
        void)        xbps-query "$1" >/dev/null 2>&1 ;;
        freebsd)     pkg info -e "$1" >/dev/null 2>&1 ;;
        *)           return 1 ;;
    esac
}

# ---------- 提权 ----------
HAVE_REAL_SUDO=false
ensure_sudo() {
    if command -v sudo >/dev/null 2>&1; then
        HAVE_REAL_SUDO=true
        return 0
    fi
    if [ "$(id -u)" -ne 0 ]; then
        fail "错误: 未找到 sudo，请以 root 身份运行此脚本，或先手动安装 sudo。"
        exit 1
    fi
    # 以 root 身份直接执行；先提供临时 sudo 兼容层，供安装 sudo 使用
    sudo() { "$@"; }
    echo "未找到 sudo，正在尝试安装..."
    pkg_update || true
    pkg_install sudo || true
    # 去掉临时函数后再检测，避免 command -v 命中函数本身
    unset -f sudo 2>/dev/null || true
    hash -r 2>/dev/null || true
    if command -v sudo >/dev/null 2>&1; then
        HAVE_REAL_SUDO=true
    else
        warn "警告: sudo 安装失败，将以 root 身份直接执行（跳过 sudo 免密配置）。"
        # 重新装上兼容层：后续所有 sudo 调用直接以 root 执行，
        # 否则 set -e 下会因 "sudo: command not found" 直接退出
        sudo() { "$@"; }
    fi
}

# ---------- 通用工具函数 ----------
# 读取用户主目录（Alpine 的 BusyBox 通常没有 getent）
get_home_dir() {
    local user=$1 home=""
    if command -v getent >/dev/null 2>&1; then
        home=$(getent passwd "$user" 2>/dev/null | cut -d: -f6) || true
    fi
    if [ -z "$home" ] && [ -r /etc/passwd ]; then
        home=$(sed -n "s|^$user:[^:]*:[^:]*:[^:]*:[^:]*:\([^:]*\):.*|\1|p" /etc/passwd)
    fi
    printf '%s\n' "$home"
}

# 把文件属主改给目标用户；组使用用户的主组（openSUSE 等已有用户的主组可能不是同名组）
chown_user() {
    local user=$1
    shift
    sudo chown "$user:$(id -gn "$user")" "$@"
}

# 本脚本生成的文件都带标记行，卸载时据此只清理自己的文件
is_our_file() {
    [ -f "$1" ] && grep -q 'VPS-ZSH-TAGBOARD' "$1" 2>/dev/null
}

# 删除本脚本生成的 .zprofile；若安装前备份过用户原有的 .zprofile，则还原备份
remove_own_zprofile() {
    local home zprofile bak f
    home=$1
    zprofile="$home/.zprofile"
    bak=""
    if [ -f "$zprofile" ]; then
        if is_our_file "$zprofile"; then
            sudo rm -f "$zprofile"
        else
            warn "警告: $zprofile 不是本脚本生成的，已保留。"
            return 0
        fi
    fi
    for f in "$home"/.zprofile.*.bak; do
        [ -f "$f" ] || continue
        bak=$f
    done
    if [ -n "$bak" ]; then
        sudo cp "$bak" "$zprofile"
        chown_user "$TARGET_USER" "$zprofile"
        echo "已从备份还原 $zprofile（备份: $(basename "$bak")）"
    fi
}

# 写入 .zprofile 前，备份用户原有的 .zprofile（非本脚本生成时才备份）
backup_user_zprofile() {
    local zprofile=$1 bak
    if [ -f "$zprofile" ] && ! is_our_file "$zprofile"; then
        bak="${zprofile}.$(date +%Y%m%d).bak"
        if [ ! -f "$bak" ]; then
            sudo cp "$zprofile" "$bak"
            chown_user "$TARGET_USER" "$bak"
            echo "已备份原有 .zprofile 至 $(basename "$bak")"
        fi
    fi
}

# 修改登录 Shell（Alpine 的 BusyBox 通常没有 chsh，回退到 usermod 或直接改 /etc/passwd）
set_login_shell() {
    local user=$1 shell=$2
    # FreeBSD 的 chsh 会校验 /etc/shells，zsh 装在 /usr/local/bin 需要先登记
    if [ -r /etc/shells ] && ! grep -qxF "$shell" /etc/shells 2>/dev/null; then
        printf '%s\n' "$shell" | sudo tee -a /etc/shells > /dev/null
    fi
    if command -v chsh >/dev/null 2>&1 && sudo chsh -s "$shell" "$user" 2>/dev/null; then
        return 0
    fi
    if command -v usermod >/dev/null 2>&1 && sudo usermod -s "$shell" "$user" 2>/dev/null; then
        return 0
    fi
    echo "提示: 未找到 chsh/usermod，直接修改 /etc/passwd 设置登录 Shell。"
    sudo cp /etc/passwd /etc/passwd.vps-zsh-tag.bak 2>/dev/null || true
    if ! sudo sed -i "s#^\($user:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\)[^:]*#\1$shell#" /etc/passwd; then
        fail "警告: 登录 Shell 修改失败，请手动执行: chsh -s $shell $user"
        return 1
    fi
}

# 交互式选择目标用户（禁止 root）
prompt_target_user() {
    local default_user="$REAL_USER"
    TARGET_USER=""
    [ "$default_user" = "root" ] && default_user=""
    while true; do
        if [ -n "$default_user" ]; then
            ask "请输入要配置的用户名 (默认 '$default_user'): " TARGET_USER
            TARGET_USER="${TARGET_USER:-$default_user}"
        else
            ask "请输入要配置的用户名 (不能为 root): " TARGET_USER
        fi
        if [ -z "$TARGET_USER" ]; then
            fail "输入错误：用户名不能为空。"
            continue
        fi
        if [ "$TARGET_USER" = "root" ]; then
            fail "安全限制：禁止对 root 执行此操作，请重新输入。"
            continue
        fi
        break
    done
}

REAL_USER="${SUDO_USER:-$(whoami)}"
ensure_sudo

# ---------- 函数定义 ----------

# 生成 .zshrc（含备份；enable_hist: true 开启历史记录 / false 关闭）
write_zshrc() {
    local home_dir=$1
    local enable_hist=$2
    local zshrc="${home_dir}/.zshrc"
    local bak_date=$(date +%Y%m%d)
    local bak_file="${home_dir}/.zshrc.${bak_date}.bak"

    if [ -f "$zshrc" ] && [ ! -f "$bak_file" ]; then
        sudo cp "$zshrc" "$bak_file"
        chown_user "$TARGET_USER" "$bak_file"
    fi

    # 第一部分：插件与补全（公共）
    sudo tee "$zshrc" > /dev/null << 'ZSHRC_HEAD_EOF'
# VPS-ZSH-TAGBOARD

# 语法高亮（兼容 Debian/Fedora 系、Arch/openSUSE/Void、Alpine、FreeBSD 的安装路径）
for _zsh_hl in \
    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    [[ -f $_zsh_hl ]] && source $_zsh_hl && break
done
unset _zsh_hl

# 自动建议（根据历史记录提示命令；兼容各发行版的插件路径）
for _zsh_as in \
    /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
    [[ -f $_zsh_as ]] && source $_zsh_as && break
done
unset _zsh_as

# 补全系统初始化
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select

# 目录/文件彩色显示 (ls 输出与 Tab 补全列表)
autoload -U colors && colors
export LS_COLORS='di=1;34:ln=1;36:so=1;35:pi=1;33:ex=1;32:bd=1;33;40:cd=1;33;40:su=1;35;41:sg=1;30;43:tw=1;33;41:ow=1;33;42'
# FreeBSD/macOS 的 ls 使用 LSCOLORS（GNU ls 会忽略这个变量）
export LSCOLORS='exfxcxdxbxegedabagacad'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
if ls --color=auto >/dev/null 2>&1; then
    alias ls='ls --color=auto'
    alias ll='ls -lh --color=auto'
    alias la='ls -lAh --color=auto'
    alias l='ls -CF --color=auto'
elif ls -G >/dev/null 2>&1; then
    # 老版本 FreeBSD 的 ls 只支持 -G
    export CLICOLOR=1
    alias ls='ls -G'
    alias ll='ls -lhG'
    alias la='ls -lAhG'
    alias l='ls -CFG'
fi

ZSHRC_HEAD_EOF

    # 第二部分：历史记录（按安装时的选项生成）
    if [ "$enable_hist" = true ]; then
        sudo tee -a "$zshrc" > /dev/null << 'ZSHRC_HIST_ON_EOF'
# 历史记录设置（已开启：保留 5000 条，跨会话共享）
HISTFILE="$HOME/.zsh_history"
HISTSIZE=5000
SAVEHIST=5000
setopt SHARE_HISTORY
setopt INTERACTIVE_COMMENTS
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search
bindkey "^[OA" up-line-or-beginning-search
bindkey "^[OB" down-line-or-beginning-search

ZSHRC_HIST_ON_EOF
    else
        sudo tee -a "$zshrc" > /dev/null << 'ZSHRC_HIST_OFF_EOF'
# 历史记录设置（未开启：不保存任何历史记录）
HISTSIZE=0
SAVEHIST=0

ZSHRC_HIST_OFF_EOF
    fi

    # 第三部分：按键与提示符（公共）
    sudo tee -a "$zshrc" > /dev/null << 'ZSHRC_TAIL_EOF'
function _tmux-ignore-focus() { :; }
zle -N _tmux-ignore-focus
bindkey "^[I" _tmux-ignore-focus
bindkey "^[O" _tmux-ignore-focus

if [[ -f /etc/os-release ]]; then
   OS_ID=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
fi
# FreeBSD 13/14 没有 /etc/os-release，用 uname 兜底
if [[ -z "$OS_ID" && "$(uname -s)" == "FreeBSD" ]]; then
   OS_ID=freebsd
fi
typeset -A colors
colors=(debian 125 ubuntu 202 kali 231 raspbian 125 pop 202 deepin 125 devuan 60
        linuxmint '#87CF3E'
        arch '#1793D1' manjaro '#35BF5C' endeavouros '#7F7FFF' cachyos '#00AEEF' garuda '#FF6B00'
        fedora '#3C6EB4' rhel '#CC0000' centos '#932279' rocky '#10B981' almalinux '#0F4266' ol '#C74634' amzn '#FF9900'
        opensuse '#73BA25' suse '#73BA25' opensuse-leap '#73BA25' opensuse-tumbleweed '#73BA25'
        void '#478061' alpine 39 freebsd '#AB2B28' default 10)
MY_CLR=${colors[$OS_ID]:-$colors[default]}
PROMPT="%F{$MY_CLR}%n@%m%f:%F{blue}%~%f%# "
ZSHRC_TAIL_EOF
}

# 安装基础 Zsh 环境（公共部分：Zsh包 + 用户 + sudo免密 + .zshrc）
setup_zsh_base() {
    say "\n${C_GREEN}>>> 开始安装 Zsh 基础环境 <<<${C_RESET}"
    pkg_update
    pkg_install zsh
    if ! command -v zsh >/dev/null 2>&1; then
        fail "错误: zsh 安装失败，无法继续。"
        exit 1
    fi

    # 看板日期改为纯整数运算，不再需要 coreutils / GNU date；Debian 保留原有的 grep 安装
    if [ "$DISTRO_FAMILY" = "debian" ]; then
        pkg_install grep || true
    fi

    # 语法高亮 / 自动建议为可选依赖，安装失败不影响基础环境
    for _plugin in zsh-syntax-highlighting zsh-autosuggestions; do
        pkg_install "$_plugin" || warn "警告: 插件 $_plugin 安装失败，已跳过。"
    done

    # 历史记录选项（默认不开启，开启后记录 5000 条）
    ask "是否开启命令历史记录？(y/N，默认不开启): " ENABLE_HIST
    case $ENABLE_HIST in
        [Yy])
            ENABLE_HIST=true
            echo "已开启：历史记录将保留 5000 条并跨会话共享。" ;;
        *)
            ENABLE_HIST=false
            echo "未开启：Zsh 不保存任何历史记录。" ;;
    esac

    # 确定目标用户（禁止 root）
    prompt_target_user

    # 用户创建（如缺失；Alpine 用 BusyBox adduser，FreeBSD 用 pw）
    IS_NEW_USER=false
    if ! id "$TARGET_USER" >/dev/null 2>&1; then
        case "$DISTRO_FAMILY" in
            alpine)  sudo adduser -D -s "$(command -v zsh)" "$TARGET_USER" ;;
            freebsd) sudo pw useradd -n "$TARGET_USER" -m -s "$(command -v zsh)" ;;
            *)       sudo useradd -m -s "$(command -v zsh)" "$TARGET_USER" ;;
        esac
        IS_NEW_USER=true
        echo "已创建用户 $TARGET_USER，默认 Shell 为 Zsh。"
    fi

    # 设置 Zsh 为默认 Shell
    set_login_shell "$TARGET_USER" "$(command -v zsh)"

    # sudo 免密（仅当系统存在真实 sudo 时）
    if [ "$HAVE_REAL_SUDO" = true ]; then
        SUDO_FILE="$SUDOERS_DIR/$TARGET_USER"
        sudo mkdir -p "$SUDOERS_DIR"
        # 确认 sudoers 真的 include 了这个目录，否则配置不会生效
        # （openSUSE 的 sudoers 默认在 /usr/etc/sudoers，同时 include /etc/sudoers.d）
        if ! sudo grep -qsE "^[#@]includedir[[:space:]]+$SUDOERS_DIR" \
                /etc/sudoers /usr/etc/sudoers /usr/local/etc/sudoers 2>/dev/null; then
            warn "警告: sudoers 未包含 $SUDOERS_DIR，免密配置可能不生效。"
        fi
        sudo tee "$SUDO_FILE" > /dev/null << SUDO_EOF
# VPS-ZSH-TAGBOARD
$TARGET_USER ALL=(ALL) NOPASSWD:ALL
SUDO_EOF
        sudo chmod 0440 "$SUDO_FILE"
    else
        warn "提示: 系统未安装 sudo，已跳过免密配置。"
    fi

    # 生成 .zshrc（含备份，历史记录按选项生成）
    TARGET_HOME=$(get_home_dir "$TARGET_USER")
    if [ -z "$TARGET_HOME" ] || [ ! -d "$TARGET_HOME" ]; then
        fail "错误: 无法确定用户 $TARGET_USER 的主目录。"
        exit 1
    fi
    write_zshrc "$TARGET_HOME" "$ENABLE_HIST"

    # 只修正本脚本生成的 .zshrc 属主，不再递归 chown 整个家目录
    chown_user "$TARGET_USER" "$TARGET_HOME/.zshrc"
}

# 完整安装（Zsh + 看板）
do_install() {
    say "\n${C_GREEN}>>> 开始完整安装 Zsh 看板 <<<${C_RESET}"
    setup_zsh_base

    # 收集看板信息与到期参数
    say "\n--- 自定义看板信息 ---"
    ask "看板 1 (厂商/用途): " IN_P
    IN_P=$(clip "$IN_P")
    ask "看板 2 (位置/归属): " IN_L
    IN_L=$(clip "$IN_L")
    ask "看板 3 (网络/警示): " IN_N
    IN_N=$(clip "$IN_N")

    echo "--- 到期设置 ---"
    while true; do
        ask "账单日 (1-31日，回车设为“永久”): " PAY_DAY
        if [ -z "$PAY_DAY" ]; then
            ADD_VAL="infinite"
            START_M="0"
            SAFE_D="0"
            break
        fi
        case $PAY_DAY in
            *[!0-9]*)
                fail "输入错误：请好好输入日期或直接回车！(╯°□°）╯︵ ┻━┻"
                continue ;;
        esac
        if [ "$PAY_DAY" -ge 1 ] && [ "$PAY_DAY" -le 31 ]; then
            while true; do
                ask "开通/续费月份 (1-12月, 默认本月): " PAY_MONTH
                if [ -z "$PAY_MONTH" ]; then
                    START_M=$(date +%m)
                    break
                fi
                case $PAY_MONTH in
                    *[!0-9]*)
                        fail "输入错误：请好好输入月份！ (╯‵□′)╯︵┻━┻"
                        continue ;;
                esac
                if [ "$PAY_MONTH" -ge 1 ] && [ "$PAY_MONTH" -le 12 ]; then
                    START_M=$PAY_MONTH
                    break
                else
                    fail "输入错误：请好好输入月份！ (╯‵□′)╯︵┻━┻"
                fi
            done
            while true; do
                echo "选择账单周期: 1.月付 2.季付 3.半年 4.年付（默认）"
                ask "请输入编号 (1-4): " CYCLE_OPT
                case ${CYCLE_OPT:-4} in
                    1) ADD_VAL="1 month"; break ;;
                    2) ADD_VAL="3 month"; break ;;
                    3) ADD_VAL="6 month"; break ;;
                    4) ADD_VAL="1 year"; break ;;
                    *) fail "输入错误：请输入编号 1-4！" ;;
                esac
            done
            SAFE_D="$PAY_DAY"
            break
        else
            fail "输入错误：请好好输入日期或直接回车！(╯°□°）╯︵ ┻━┻"
        fi
    done

    # 系统静态信息（FreeBSD 没有 /proc，改用 sysctl；探测失败时回退到安全默认值）
    if [ "$DISTRO_FAMILY" = "freebsd" ]; then
        _cpu=$(sysctl -n hw.ncpu 2>/dev/null || true)
        _mem_kb=$(( $(sysctl -n hw.physmem 2>/dev/null || echo 0) / 1024 ))
    else
        _cpu=$(nproc 2>/dev/null || true)
        if [ -z "$_cpu" ]; then
            _cpu=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || true)
        fi
        # 不用 awk：openSUSE 等最小镜像可能没装 gawk/mawk
        _mem_kb=""
        if [ -r /proc/meminfo ]; then
            while read -r _key _val _rest; do
                if [ "$_key" = "MemTotal:" ]; then
                    _mem_kb=$_val
                    break
                fi
            done < /proc/meminfo
        fi
    fi
    case ${_cpu:-} in
        ''|*[!0-9]*) CPU_CORES=1 ;;
        *)           CPU_CORES=$_cpu ;;
    esac
    [ "$CPU_CORES" -ge 1 ] || CPU_CORES=1
    case ${_mem_kb:-} in
        ''|*[!0-9]*) _mem_kb=0 ;;
    esac
    MEM_RAW=$(( _mem_kb / 1024 ))
    if [ "$MEM_RAW" -lt 1 ]; then
        MEM_SIZE="?MB"
    elif [ "$MEM_RAW" -lt 900 ]; then
        MEM_SIZE="${MEM_RAW}MB"
    else
        MEM_SIZE="$(( (MEM_RAW + 512) / 1024 ))GB"
    fi
    OS_NAME=$(grep "PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d '"' -f 2 || uname -sr)
    [ -n "$OS_NAME" ] || OS_NAME=$(uname -sr)

    # TARGET_HOME 已由 setup_zsh_base 设置

    # 写入配置文件（单引号转义，zsh source 时不会二次展开）
    CONF_FILE="${TARGET_HOME}/.welcome.conf"
    {
        printf "IN_P='%s'\n"      "$(sq "$IN_P")"
        printf "IN_L='%s'\n"      "$(sq "$IN_L")"
        printf "IN_N='%s'\n"      "$(sq "$IN_N")"
        printf "ADD_VAL='%s'\n"   "$(sq "$ADD_VAL")"
        printf "SAFE_D='%s'\n"    "$(sq "$SAFE_D")"
        printf "START_M='%s'\n"   "$(sq "$START_M")"
        printf "CPU_CORES='%s'\n" "$(sq "$CPU_CORES")"
        printf "MEM_SIZE='%s'\n"  "$(sq "$MEM_SIZE")"
        printf "OS_NAME='%s'\n"   "$(sq "$OS_NAME")"
    } | sudo tee "$CONF_FILE" > /dev/null

    # 写欢迎看板脚本
    WELCOME_SH="${TARGET_HOME}/.welcome.sh"
    sudo tee "$WELCOME_SH" > /dev/null << 'WELCOME_EOF'
#!/bin/zsh
# VPS-ZSH-TAGBOARD
source ~/.welcome.conf

zmodload zsh/datetime

# 公历整数运算，不依赖外部 date / gdate：
# 距 1970-01-01 的天数（proleptic Gregorian，含 100/400 闰年规则）
_days_from_civil() {
    local y=$1 m=$2 d=$3
    (( m <= 2 )) && (( y-- ))
    local era=$(( (y >= 0 ? y : y-399) / 400 ))
    local yoe=$(( y - era*400 ))
    local doy=$(( (153*(m + (m > 2 ? -3 : 9)) + 2)/5 + d - 1 ))
    REPLY=$(( era*146097 + yoe*365 + yoe/4 - yoe/100 + doy - 719468 ))
}

_days_in_month() {
    local y=$1 m=$2
    case $m in
        2) if (( y % 4 == 0 && (y % 100 != 0 || y % 400 == 0) )); then REPLY=29; else REPLY=28; fi ;;
        4|6|9|11) REPLY=30 ;;
        *) REPLY=31 ;;
    esac
}

WHITE='\e[0;37m'
RED='\e[1;31m'
YELLOW='\033[1;33m'
RESET='\e[0m'

if [ "$ADD_VAL" = "infinite" ]; then
    DISP="${WHITE}∞"
else
    case $ADD_VAL in
        "1 month") CYCLE_M=1 ;;
        "3 month") CYCLE_M=3 ;;
        "6 month") CYCLE_M=6 ;;
        *)         CYCLE_M=12 ;;
    esac

    strftime -s _today %Y-%m-%d
    _ty=$(( 10#${_today[1,4]} ))
    _tm=$(( 10#${_today[6,7]} ))
    _td=$(( 10#${_today[9,10]} ))
    _days_from_civil $_ty $_tm $_td
    _today_days=$REPLY

    ANCHOR_D=$(( 10#$SAFE_D ))
    INIT_M=$(( 10#$START_M ))
    _y=$_ty
    _m=$INIT_M
    _guard=0
    while (( _guard < 100 )); do
        _days_in_month $_y $_m
        _last=$REPLY
        if (( ANCHOR_D > _last )); then _d=$_last; else _d=$ANCHOR_D; fi
        _days_from_civil $_y $_m $_d
        _cur=$REPLY
        (( _cur >= _today_days )) && break
        _t=$(( _y*12 + (_m-1) + CYCLE_M ))
        _y=$(( _t / 12 ))
        _m=$(( _t % 12 + 1 ))
        (( _guard++ ))
    done

    printf -v EXP_DATE '%04d-%02d-%02d' $_y $_m $_d
    DAYS_LEFT=$(( _cur - _today_days ))

    if [ "$DAYS_LEFT" -lt 0 ]; then
        DISP="${RED}配置异常 (✘﹏✘)"
    elif [ "$DAYS_LEFT" -eq 0 ]; then
        DISP="${YELLOW}到期啦，就是今天！(๑•̀ㅂ•́)و✧"
    else
        if [ "$DAYS_LEFT" -le 7 ]; then
            DISP="${WHITE}$EXP_DATE ${RED}(${DAYS_LEFT}d)"
        else
            DISP="${WHITE}$EXP_DATE (${DAYS_LEFT}d)"
        fi
    fi
fi

TAGS=""
for val in "$IN_P" "$IN_L" "$IN_N"; do
    [ -n "$val" ] && TAGS="${TAGS:+$TAGS • }$val"
done

if [ "$ADD_VAL" = "infinite" ] && [ -z "$TAGS" ]; then
    DISP=""
fi

echo ""
echo -e "${WHITE}[$OS_NAME] ${CPU_CORES}C/${MEM_SIZE}${RESET}"
# DISP 与 TAGS 都为空（跳过看板且无标签）时连标签行一起省略，避免输出空行
if [ -n "$DISP$TAGS" ]; then
    _sep=""
    [ -n "$DISP" ] && [ -n "$TAGS" ] && _sep=" • "
    echo -e "$DISP${WHITE}${_sep}${TAGS}${RESET}"
fi
echo ""
WELCOME_EOF

    sudo chmod +x "$WELCOME_SH"

    # 创建 .zprofile 自动加载（若用户原有的 .zprofile 不是本脚本生成的，先备份）
    ZPROFILE="${TARGET_HOME}/.zprofile"
    backup_user_zprofile "$ZPROFILE"
    sudo tee "$ZPROFILE" > /dev/null << 'ZPROFILE_EOF'
# VPS-ZSH-TAGBOARD
# 交互式登录 Shell 会由 zsh 自己读取 ~/.zshrc，这里只在非交互登录时补加载，避免重复执行
if [[ ! -o interactive && -f ~/.zshrc ]]; then
    source ~/.zshrc
fi
[[ -f ~/.welcome.sh ]] && source ~/.welcome.sh
ZPROFILE_EOF

    # 统一修正权限（只处理本脚本生成的文件，不递归 chown 整个家目录）
    chown_user "$TARGET_USER" "$CONF_FILE" "$WELCOME_SH" "$ZPROFILE"

    say "\n${C_GREEN}状态: 配置完成！${C_RESET}"
    echo "------------------------------------------------"
    echo "1. 立即切换环境: exec su - $TARGET_USER"
    [ "$IS_NEW_USER" = true ] && echo "2. 新用户设置密码: sudo passwd $TARGET_USER"
    echo "备份提示: 原始 .zshrc 已备份至 ~/.zshrc.XXXXXXXX.bak"
    echo "------------------------------------------------"
}

# 仅安装 Zsh（不含看板）
do_install_zsh_only() {
    say "\n${C_GREEN}>>> 仅安装 Zsh 基础环境 <<<${C_RESET}"
    setup_zsh_base

    say "\n${C_GREEN}状态: Zsh 基础环境配置完成！${C_RESET}"
    echo "------------------------------------------------"
    echo "1. 立即切换环境: exec su - $TARGET_USER"
    [ "$IS_NEW_USER" = true ] && echo "2. 新用户设置密码: sudo passwd $TARGET_USER"
    echo "备份提示: 原始 .zshrc 已备份至 ~/.zshrc.XXXXXXXX.bak"
    echo "------------------------------------------------"
}

# 仅移除看板
do_remove_welcome() {
    prompt_target_user

    TARGET_HOME=$(get_home_dir "$TARGET_USER")
    if [ -z "$TARGET_HOME" ]; then
        fail "错误: 用户 $TARGET_USER 不存在。"
        return 1
    fi
    say "\n${C_YELLOW}即将清理看板文件（.zprofile 若为脚本生成则删除并还原备份，否则保留）：${C_RESET}"
    for f in "$TARGET_HOME/.welcome.sh" "$TARGET_HOME/.welcome.conf" "$TARGET_HOME/.zprofile"; do
        if [ -f "$f" ]; then
            echo "  $f"
        fi
    done
    ask "确认删除？(y/N): " CONFIRM
    case $CONFIRM in
        [Yy]) ;;
        *) echo "已取消。"; return ;;
    esac

    sudo rm -f "$TARGET_HOME/.welcome.sh" "$TARGET_HOME/.welcome.conf"
    remove_own_zprofile "$TARGET_HOME"
    say "${C_GREEN}看板及相关文件已移除，Zsh 配置本身未改动。${C_RESET}"
}

# 彻底卸载：还原 Shell、移除看板、可选清除 Zsh 和 sudo 配置
do_uninstall() {
    prompt_target_user

    case "$DISTRO_FAMILY" in
        alpine)
            # Alpine 的默认登录 Shell 为 /bin/ash（BusyBox），退回 /bin/sh
            RESTORE_SHELL="/bin/ash" ;;
        freebsd)
            # FreeBSD 普通用户默认是 /bin/sh（root 才是 /bin/csh）
            RESTORE_SHELL="/bin/sh" ;;
        *)
            RESTORE_SHELL="/bin/bash" ;;
    esac
    { [ -e "$RESTORE_SHELL" ] || [ -L "$RESTORE_SHELL" ]; } || RESTORE_SHELL="/bin/sh"

    fail "\n警告：即将对用户 $TARGET_USER 执行彻底卸载！"
    echo "操作包括："
    echo "  - 将默认 Shell 还原为 $RESTORE_SHELL"
    echo "  - 删除看板文件 (~/.welcome.sh, ~/.welcome.conf)"
    echo "  - 还原安装前的 ~/.zprofile 备份（如有）"
    echo "  - 移除 sudo 免密配置 ($SUDOERS_DIR/$TARGET_USER)"
    echo "  - (可选) 彻底移除 Zsh 包"
    ask "确认继续？(y/N): " CONFIRM
    case $CONFIRM in
        [Yy]) ;;
        *) echo "已取消。"; return ;;
    esac

    # 还原 Shell
    if ! set_login_shell "$TARGET_USER" "$RESTORE_SHELL"; then
        echo "警告: 还原 Shell 失败，请手动执行 chsh -s $RESTORE_SHELL $TARGET_USER"
    fi

    # 移除看板文件（.zprofile 仅在确认是本脚本生成时才删除，随后还原备份）
    TARGET_HOME=$(get_home_dir "$TARGET_USER")
    if [ -n "$TARGET_HOME" ]; then
        sudo rm -f "$TARGET_HOME/.welcome.sh" "$TARGET_HOME/.welcome.conf"
        remove_own_zprofile "$TARGET_HOME"
    else
        echo "警告: 未找到用户 $TARGET_USER，跳过看板文件清理。"
    fi

    # 移除 sudo 免密配置
    SUDO_FILE="$SUDOERS_DIR/$TARGET_USER"
    if [ -f "$SUDO_FILE" ]; then
        sudo rm -f "$SUDO_FILE"
        echo "已移除 sudo 免密配置。"
    fi

    # 询问是否移除 Zsh 包
    ask "是否彻底移除 Zsh 软件包？(y/N): " PURGE_ZSH
    case $PURGE_ZSH in
        [Yy])
            # 只传入已安装的包，避免某个插件当初没装上导致整条移除命令失败
            PURGE_LIST=""
            for _p in zsh zsh-syntax-highlighting zsh-autosuggestions; do
                if pkg_installed "$_p"; then
                    PURGE_LIST="$PURGE_LIST $_p"
                fi
            done
            if [ -z "$PURGE_LIST" ]; then
                echo "未发现需要移除的 Zsh 相关包。"
            # 故意不加引号，让 PURGE_LIST 按空格拆成多个包名
            elif pkg_purge $PURGE_LIST; then
                echo "Zsh 及相关包已移除。"
            else
                echo "警告: 部分 Zsh 相关包移除失败，请手动移除。"
            fi ;;
    esac

    say "${C_GREEN}卸载完成。请手动检查 .zshrc 是否需要删除（如不再使用 Zsh）。${C_RESET}"
}

# ---------- 主菜单 ----------
echo "==================================="
echo "    看板管理脚本"
echo "==================================="
echo "  1) 完整安装"
echo "  2) 仅安装Zsh"
echo "  3) 卸载看板"
echo "  4) 彻底卸载"
echo "==================================="
ask "请输入编号 (1-4，默认1): " MENU_OPT
MENU_OPT="${MENU_OPT:-1}"

case "$MENU_OPT" in
    1) do_install ;;
    2) do_install_zsh_only ;;
    3) do_remove_welcome ;;
    4) do_uninstall ;;
    *) echo "无效选项，退出。"; exit 1 ;;
esac
