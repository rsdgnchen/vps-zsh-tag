#!/bin/bash
# ==========================================================
# 脚本名称: Debian / Alpine 通用 Zsh 看板脚本 (精简菜单版)
# 支持系统: Debian 及其衍生版 (Ubuntu/Kali/...)、Alpine Linux
# ==========================================================

# ---------- 以 bash 重新执行（Alpine 等默认不含 bash 的系统） ----------
if [ -z "${BASH_VERSION:-}" ]; then
    if [ -r "${0:-}" ]; then
        if ! command -v bash >/dev/null 2>&1; then
            if [ "$(id -u)" -eq 0 ] && command -v apk >/dev/null 2>&1; then
                echo "未找到 bash，正在通过 apk 安装..."
                apk add --no-cache bash
            else
                echo "错误: 本脚本需要 bash，请先安装（Alpine: apk add --no-cache bash）。"
                exit 1
            fi
        fi
        exec bash "$0" "$@"
    fi
    echo "错误: 请使用 bash 运行本脚本（Alpine: apk add --no-cache bash）。"
    exit 1
fi

set -euo pipefail

# ---------- 发行版检测 ----------
if [ -f /etc/alpine-release ]; then
    DISTRO_FAMILY="alpine"
elif [ -f /etc/debian_version ]; then
    DISTRO_FAMILY="debian"
else
    echo "错误: 此脚本仅支持 Debian 及其衍生版、Alpine Linux。"
    exit 1
fi

# ---------- 包管理器封装 ----------
pkg_update() {
    case "$DISTRO_FAMILY" in
        alpine) sudo apk update ;;
        debian) sudo apt update ;;
    esac
}

pkg_install() {
    case "$DISTRO_FAMILY" in
        alpine) sudo apk add "$@" ;;
        debian) sudo apt install -y "$@" ;;
    esac
}

pkg_purge() {
    case "$DISTRO_FAMILY" in
        alpine) sudo apk del "$@" ;;
        debian) sudo apt remove --purge -y "$@" && sudo apt autoremove --purge -y ;;
    esac
}

# ---------- 提权 ----------
HAVE_REAL_SUDO=false
ensure_sudo() {
    if type -P sudo >/dev/null 2>&1; then
        HAVE_REAL_SUDO=true
        return 0
    fi
    if [ "$(id -u)" -ne 0 ]; then
        echo "错误: 未找到 sudo，请以 root 身份运行此脚本，或先手动安装 sudo。"
        exit 1
    fi
    # 以 root 身份直接执行；先提供临时 sudo 兼容层，供安装 sudo 使用
    sudo() { "$@"; }
    echo "未找到 sudo，正在尝试安装..."
    pkg_update || true
    pkg_install sudo || true
    if type -P sudo >/dev/null 2>&1; then
        HAVE_REAL_SUDO=true
        unset -f sudo
    else
        echo -e "\e[1;33m警告: sudo 安装失败，将以 root 身份直接执行（跳过 sudo 免密配置）。\e[0m"
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
        home=$(awk -F: -v u="$user" '$1==u {print $6; exit}' /etc/passwd)
    fi
    printf '%s\n' "$home"
}

# 修改登录 Shell（Alpine 的 BusyBox 通常没有 chsh，回退到 usermod 或直接改 /etc/passwd）
set_login_shell() {
    local user=$1 shell=$2
    if command -v chsh >/dev/null 2>&1 && sudo chsh -s "$shell" "$user" 2>/dev/null; then
        return 0
    fi
    if command -v usermod >/dev/null 2>&1 && sudo usermod -s "$shell" "$user" 2>/dev/null; then
        return 0
    fi
    echo "提示: 未找到 chsh/usermod，直接修改 /etc/passwd 设置登录 Shell。"
    sudo cp /etc/passwd /etc/passwd.vps-zsh-tag.bak 2>/dev/null || true
    if ! sudo sed -i "s#^\($user:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\)[^:]*#\1$shell#" /etc/passwd; then
        echo -e "\e[1;31m警告: 登录 Shell 修改失败，请手动执行: chsh -s $shell $user\e[0m"
        return 1
    fi
}

# 交互式选择目标用户（禁止 root）
prompt_target_user() {
    local default_user="$REAL_USER"
    [ "$default_user" = "root" ] && default_user=""
    while true; do
        if [ -n "$default_user" ]; then
            read -re -p "请输入要配置的用户名 (默认 '$default_user'): " TARGET_USER
            TARGET_USER="${TARGET_USER:-$default_user}"
        else
            read -re -p "请输入要配置的用户名 (不能为 root): " TARGET_USER
        fi
        if [ -z "$TARGET_USER" ]; then
            echo -e "\e[1;31m输入错误：用户名不能为空。\e[0m"
            continue
        fi
        if [ "$TARGET_USER" = "root" ]; then
            echo -e "\e[1;31m安全限制：禁止对 root 执行此操作，请重新输入。\e[0m"
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
    fi

    # 第一部分：插件与补全（公共）
    sudo tee "$zshrc" > /dev/null << 'ZSHRC_HEAD_EOF'
# VPS-ZSH-TAGBOARD

# 语法高亮（兼容 Debian / Alpine 的安装路径）
for _zsh_hl in \
    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    [[ -f $_zsh_hl ]] && source $_zsh_hl && break
done
unset _zsh_hl

# 自动建议（根据历史记录提示命令；兼容 Debian / Alpine 路径）
for _zsh_as in \
    /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
    [[ -f $_zsh_as ]] && source $_zsh_as && break
done
unset _zsh_as

# 补全系统初始化
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select

# 目录/文件彩色显示 (ls 输出与 Tab 补全列表)
autoload -U colors && colors
export LS_COLORS='di=1;34:ln=1;36:so=1;35:pi=1;33:ex=1;32:bd=1;33;40:cd=1;33;40:su=1;35;41:sg=1;30;43:tw=1;33;41:ow=1;33;42'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
if ls --color=auto >/dev/null 2>&1; then
    alias ls='ls --color=auto'
    alias ll='ls -lh --color=auto'
    alias la='ls -lAh --color=auto'
    alias l='ls -CF --color=auto'
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
typeset -A colors
colors=(debian 125 ubuntu 202 kali 231 raspbian 125 pop 202 deepin 125 devuan 60 alpine 39 default 10)
MY_CLR=${colors[$OS_ID]:-$colors[default]}
PROMPT="%F{$MY_CLR}%n@%m%f:%F{blue}%~%f%# "
ZSHRC_TAIL_EOF
}

# 安装基础 Zsh 环境（公共部分：Zsh包 + 用户 + sudo免密 + .zshrc）
setup_zsh_base() {
    echo -e "\n\e[1;32m>>> 开始安装 Zsh 基础环境 <<<\e[0m"
    pkg_update
    pkg_install zsh
    if ! command -v zsh >/dev/null 2>&1; then
        echo -e "\e[1;31m错误: zsh 安装失败，无法继续。\e[0m"
        exit 1
    fi

    # Debian 需要 grep；Alpine 需要 coreutils（GNU date/ls，看板日期与彩色输出依赖）
    if [ "$DISTRO_FAMILY" = "alpine" ]; then
        pkg_install coreutils || echo -e "\e[1;33m警告: coreutils 安装失败，看板日期计算可能异常。\e[0m"
    else
        pkg_install grep || true
    fi

    # 语法高亮 / 自动建议为可选依赖，安装失败不影响基础环境
    for _plugin in zsh-syntax-highlighting zsh-autosuggestions; do
        pkg_install "$_plugin" || echo -e "\e[1;33m警告: 插件 $_plugin 安装失败，已跳过。\e[0m"
    done

    # 历史记录选项（默认不开启，开启后记录 5000 条）
    read -re -p "是否开启命令历史记录？(y/N，默认不开启): " ENABLE_HIST
    if [[ "$ENABLE_HIST" =~ ^[Yy]$ ]]; then
        ENABLE_HIST=true
        echo "已开启：历史记录将保留 5000 条并跨会话共享。"
    else
        ENABLE_HIST=false
        echo "未开启：Zsh 不保存任何历史记录。"
    fi

    # 确定目标用户（禁止 root）
    prompt_target_user

    # 用户创建（如缺失；Alpine 使用 BusyBox 的 adduser）
    IS_NEW_USER=false
    if ! id "$TARGET_USER" &>/dev/null; then
        if [ "$DISTRO_FAMILY" = "alpine" ]; then
            sudo adduser -D -s "$(command -v zsh)" "$TARGET_USER"
        else
            sudo useradd -m -s "$(command -v zsh)" "$TARGET_USER"
        fi
        IS_NEW_USER=true
        echo "已创建用户 $TARGET_USER，默认 Shell 为 Zsh。"
    fi

    # 设置 Zsh 为默认 Shell
    set_login_shell "$TARGET_USER" "$(command -v zsh)"

    # sudo 免密（仅当系统存在真实 sudo 时）
    if [ "$HAVE_REAL_SUDO" = true ]; then
        SUDO_FILE="/etc/sudoers.d/$TARGET_USER"
        sudo tee "$SUDO_FILE" > /dev/null << SUDO_EOF
# VPS-ZSH-TAGBOARD
$TARGET_USER ALL=(ALL) NOPASSWD:ALL
SUDO_EOF
        sudo chmod 0440 "$SUDO_FILE"
    else
        echo -e "\e[1;33m提示: 系统未安装 sudo，已跳过免密配置。\e[0m"
    fi

    # 生成 .zshrc（含备份，历史记录按选项生成）
    TARGET_HOME=$(get_home_dir "$TARGET_USER")
    if [ -z "$TARGET_HOME" ] || [ ! -d "$TARGET_HOME" ]; then
        echo -e "\e[1;31m错误: 无法确定用户 $TARGET_USER 的主目录。\e[0m"
        exit 1
    fi
    write_zshrc "$TARGET_HOME" "$ENABLE_HIST"

    # 修正权限
    sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"
}

# 完整安装（Zsh + 看板）
do_install() {
    echo -e "\n\e[1;32m>>> 开始完整安装 Zsh 看板 <<<\e[0m"
    setup_zsh_base

    # 收集看板信息与到期参数
    echo -e "\n--- 自定义看板信息 ---"
    read -re -p "看板 1 (厂商/用途): " IN_P
    IN_P="${IN_P:0:120}"
    read -re -p "看板 2 (位置/归属): " IN_L
    IN_L="${IN_L:0:120}"
    read -re -p "看板 3 (网络/警示): " IN_N
    IN_N="${IN_N:0:120}"

    echo "--- 到期设置 ---"
    while true; do
        read -re -p "账单日 (1-31日，回车设为“永久”): " PAY_DAY
        if [[ -z "$PAY_DAY" ]]; then
            ADD_VAL="infinite"
            START_M="0"
            SAFE_D="0"
            break
        elif [[ "$PAY_DAY" =~ ^[0-9]+$ ]] && [ "$PAY_DAY" -ge 1 ] && [ "$PAY_DAY" -le 31 ]; then
            while true; do
                read -re -p "开通/续费月份 (1-12月, 默认本月): " PAY_MONTH
                if [[ -z "$PAY_MONTH" ]]; then
                    START_M=$(date +%m)
                    break
                elif [[ "$PAY_MONTH" =~ ^[0-9]+$ ]] && [ "$PAY_MONTH" -ge 1 ] && [ "$PAY_MONTH" -le 12 ]; then
                    START_M=$PAY_MONTH
                    break
                else
                    echo -e "\e[1;31m输入错误：请好好输入月份！ (╯‵□′)╯︵┻━┻ \e[0m"
                fi
            done
            while true; do
                echo "选择账单周期: 1.月付 2.季付 3.半年 4.年付（默认）"
                read -rep "请输入编号 (1-4): " CYCLE_OPT
                case ${CYCLE_OPT:-4} in
                    1) ADD_VAL="1 month"; break ;;
                    2) ADD_VAL="3 month"; break ;;
                    3) ADD_VAL="6 month"; break ;;
                    4) ADD_VAL="1 year"; break ;;
                    *) echo -e "\e[1;31m输入错误：请输入编号 1-4！\e[0m" ;;
                esac
            done
            SAFE_D="$PAY_DAY"
            break
        else
            echo -e "\e[1;31m输入错误：请好好输入日期或直接回车！(╯°□°）╯︵ ┻━┻ \e[0m"
        fi
    done

    # 系统静态信息
    CPU_CORES=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)
    MEM_RAW=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
    if [ "$MEM_RAW" -lt 900 ]; then
        MEM_SIZE="${MEM_RAW}MB"
    else
        MEM_SIZE="$(( (MEM_RAW + 512) / 1024 ))GB"
    fi
    OS_NAME=$(grep "PRETTY_NAME" /etc/os-release | cut -d '"' -f 2 || uname -sr)

    # TARGET_HOME 已由 setup_zsh_base 设置

    # 写入配置文件（安全方式）
    CONF_FILE="${TARGET_HOME}/.welcome.conf"
    {
        declare -p IN_P IN_L IN_N ADD_VAL SAFE_D START_M CPU_CORES MEM_SIZE OS_NAME
    } | sudo tee "$CONF_FILE" > /dev/null
    sudo chown "$TARGET_USER:$TARGET_USER" "$CONF_FILE"

    # 写欢迎看板脚本
    WELCOME_SH="${TARGET_HOME}/.welcome.sh"
    sudo tee "$WELCOME_SH" > /dev/null << 'WELCOME_EOF'
#!/bin/zsh
source ~/.welcome.conf

# Alpine/BusyBox 兼容性检查：到期计算依赖 GNU date（Alpine 需安装 coreutils）
if ! date -d "2000-01-01 +1 month -1 day" +%d >/dev/null 2>&1; then
    echo -e "\e[1;33m[VPS-ZSH-TAG] 未检测到 GNU date，请安装 coreutils（Alpine: apk add coreutils）后重新登录。\e[0m"
    return 0 2>/dev/null || exit 0
fi

WHITE='\e[0;37m'
RED='\e[1;31m'
YELLOW='\033[1;33m'
RESET='\e[0m'

if [ "$ADD_VAL" = "infinite" ]; then
    DISP="${WHITE}∞"
else
    ANCHOR_D=$SAFE_D
    ADD_STR="$ADD_VAL"
    INIT_M=$START_M
    INIT_Y=$(date +%Y)

    NOW_TS=$(date +%s)
    LAST_D_INIT=$(date -d "$INIT_Y-$INIT_M-01 +1 month -1 day" +%d)
    [ "$ANCHOR_D" -gt "$LAST_D_INIT" ] && ACT_D=$LAST_D_INIT || ACT_D=$ANCHOR_D
    TARGET_TS=$(date -d "$INIT_Y-$INIT_M-$ACT_D 23:59:59" +%s)

    LOOP_GUARD=0
    while [ "$TARGET_TS" -lt "$NOW_TS" ] && [ "$LOOP_GUARD" -lt 100 ]; do
        CUR_Y=$(date -d "@$TARGET_TS" +%Y)
        CUR_M=$(date -d "@$TARGET_TS" +%m)
        NEXT_BASE_Y=$(date -d "$CUR_Y-$CUR_M-01 + $ADD_STR" +%Y)
        NEXT_BASE_M=$(date -d "$CUR_Y-$CUR_M-01 + $ADD_STR" +%m)
        LAST_D_NEXT=$(date -d "$NEXT_BASE_Y-$NEXT_BASE_M-01 +1 month -1 day" +%d)
        [ "$ANCHOR_D" -gt "$LAST_D_NEXT" ] && ACT_D=$LAST_D_NEXT || ACT_D=$ANCHOR_D
        TARGET_TS=$(date -d "$NEXT_BASE_Y-$NEXT_BASE_M-$ACT_D 23:59:59" +%s)
        ((LOOP_GUARD++))
    done

    EXP_DATE=$(date -d "@$TARGET_TS" +%Y-%m-%d)
    TODAY_ZERO=$(date -d "$(date +%Y-%m-%d) 00:00:00" +%s)
    DAYS_LEFT=$(( (TARGET_TS - TODAY_ZERO) / 86400 ))

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
    [ -n "$val" ] && TAGS="$TAGS • $val"
done

if [ "$ADD_VAL" = "infinite" ] && [ -z "$TAGS" ]; then
    DISP=""
fi

echo ""
echo -e "${WHITE}[$OS_NAME] ${CPU_CORES}C/${MEM_SIZE}${RESET}"
echo -e "$DISP${WHITE}$TAGS ${RESET}"
echo ""
WELCOME_EOF

    sudo chmod +x "$WELCOME_SH"

    # 创建 .zprofile 自动加载
    ZPROFILE="${TARGET_HOME}/.zprofile"
    sudo tee "$ZPROFILE" > /dev/null << 'ZPROFILE_EOF'
[[ -f ~/.zshrc ]] && source ~/.zshrc
[[ -f ~/.welcome.sh ]] && source ~/.welcome.sh
ZPROFILE_EOF

    # 统一修正权限
    sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"

    echo -e "\n\e[1;32m状态: 配置完成！\e[0m"
    echo "------------------------------------------------"
    echo "1. 立即切换环境: exec su - $TARGET_USER"
    [ "$IS_NEW_USER" = true ] && echo "2. 新用户设置密码: sudo passwd $TARGET_USER"
    echo "备份提示: 原始 .zshrc 已备份至 ~/.zshrc.XXXXXXXX.bak"
    echo "------------------------------------------------"
}

# 仅安装 Zsh（不含看板）
do_install_zsh_only() {
    echo -e "\n\e[1;32m>>> 仅安装 Zsh 基础环境 <<<\e[0m"
    setup_zsh_base

    echo -e "\n\e[1;32m状态: Zsh 基础环境配置完成！\e[0m"
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
        echo -e "\e[1;31m错误: 用户 $TARGET_USER 不存在。\e[0m"
        return 1
    fi
    FILES=("$TARGET_HOME/.welcome.sh" "$TARGET_HOME/.welcome.conf" "$TARGET_HOME/.zprofile")
    echo -e "\n\e[1;33m即将删除以下文件 (若存在)：\e[0m"
    for f in "${FILES[@]}"; do
        [ -f "$f" ] && echo "  $f"
    done
    read -re -p "确认删除？(y/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "已取消。"
        return
    fi

    for f in "${FILES[@]}"; do
        sudo rm -f "$f"
    done
    echo -e "\e[1;32m看板及相关文件已移除，Zsh 配置本身未改动。\e[0m"
}

# 彻底卸载：还原 Shell、移除看板、可选清除 Zsh 和 sudo 配置
do_uninstall() {
    prompt_target_user

    if [ "$DISTRO_FAMILY" = "alpine" ]; then
        # Alpine 的默认登录 Shell 为 /bin/ash（BusyBox），退回 /bin/sh
        RESTORE_SHELL="/bin/ash"
        { [ -e "$RESTORE_SHELL" ] || [ -L "$RESTORE_SHELL" ]; } || RESTORE_SHELL="/bin/sh"
    else
        RESTORE_SHELL="/bin/bash"
        { [ -e "$RESTORE_SHELL" ] || [ -L "$RESTORE_SHELL" ]; } || RESTORE_SHELL="/bin/sh"
    fi

    echo -e "\n\e[1;31m警告：即将对用户 $TARGET_USER 执行彻底卸载！\e[0m"
    echo "操作包括："
    echo "  - 将默认 Shell 还原为 $RESTORE_SHELL"
    echo "  - 删除看板文件 (~/.welcome.sh, ~/.welcome.conf, ~/.zprofile)"
    echo "  - 移除 sudo 免密配置 (/etc/sudoers.d/$TARGET_USER)"
    echo "  - (可选) 彻底移除 Zsh 包"
    read -re -p "确认继续？(y/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "已取消。"
        return
    fi

    # 还原 Shell
    if ! set_login_shell "$TARGET_USER" "$RESTORE_SHELL"; then
        echo "警告: 还原 Shell 失败，请手动执行 chsh -s $RESTORE_SHELL $TARGET_USER"
    fi

    # 移除看板文件
    TARGET_HOME=$(get_home_dir "$TARGET_USER")
    if [ -n "$TARGET_HOME" ]; then
        sudo rm -f "$TARGET_HOME/.welcome.sh" "$TARGET_HOME/.welcome.conf" "$TARGET_HOME/.zprofile"
    else
        echo "警告: 未找到用户 $TARGET_USER，跳过看板文件清理。"
    fi

    # 移除 sudo 免密配置
    SUDO_FILE="/etc/sudoers.d/$TARGET_USER"
    if [ -f "$SUDO_FILE" ]; then
        sudo rm -f "$SUDO_FILE"
        echo "已移除 sudo 免密配置。"
    fi

    # 询问是否移除 Zsh 包
    read -re -p "是否彻底移除 Zsh 软件包？(y/N): " PURGE_ZSH
    if [[ "$PURGE_ZSH" =~ ^[Yy]$ ]]; then
        if [ "$DISTRO_FAMILY" = "alpine" ]; then
            if pkg_purge zsh zsh-syntax-highlighting zsh-autosuggestions; then
                echo "Zsh 及相关包已移除。"
            else
                echo "警告: 部分 Zsh 相关包移除失败，请手动执行 apk del。"
            fi
        else
            if pkg_purge zsh; then
                echo "Zsh 包已移除。"
            else
                echo "警告: Zsh 包移除失败。"
            fi
        fi
    fi

    echo -e "\e[1;32m卸载完成。请手动检查 .zshrc 是否需要删除（如不再使用 Zsh）。\e[0m"
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
read -re -p "请输入编号 (1-4，默认1): " MENU_OPT
MENU_OPT="${MENU_OPT:-1}"

case "$MENU_OPT" in
    1) do_install ;;
    2) do_install_zsh_only ;;
    3) do_remove_welcome ;;
    4) do_uninstall ;;
    *) echo "无效选项，退出。"; exit 1 ;;
esac