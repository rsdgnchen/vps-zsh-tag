#!/bin/bash
# ==========================================================
# 脚本名称: Debian 延伸版专用 Zsh 看板脚本 (精简菜单版)
# ==========================================================
set -euo pipefail

# ---------- 基础环境与提权 ----------
if ! command -v sudo &>/dev/null; then
    if [ "$(id -u)" -eq 0 ]; then
        apt update && apt install sudo -y
    else
        echo "错误: 请以 root 身份运行此脚本。"
        exit 1
    fi
fi

if [ ! -f /etc/debian_version ]; then
    echo "错误: 此脚本仅支持 Debian 及其衍生版。"
    exit 1
fi

REAL_USER="${SUDO_USER:-$(whoami)}"

# ---------- 函数定义 ----------
# 安装或覆盖安装
do_install() {
    echo -e "\n\e[1;32m>>> 开始安装/覆盖安装 Zsh 看板 <<<\e[0m"
    sudo apt update && sudo apt install zsh grep -y

    # 确定目标用户（禁止 root）
    while true; do
        read -re -p "请输入要配置的用户名 (默认 '$REAL_USER'): " TARGET_USER
        TARGET_USER="${TARGET_USER:-$REAL_USER}"
        if [ "$TARGET_USER" = "root" ]; then
            echo -e "\e[1;31m安全限制：禁止对 root 执行此操作，请重新输入。\e[0m"
            continue
        fi
        break
    done

    # 用户创建（如缺失）
    IS_NEW_USER=false
    if ! id "$TARGET_USER" &>/dev/null; then
        sudo useradd -m -s "$(which zsh)" "$TARGET_USER"
        IS_NEW_USER=true
        echo "已创建用户 $TARGET_USER，默认 Shell 为 Zsh。"
    fi

    # sudo 免密
    SUDO_FILE="/etc/sudoers.d/$TARGET_USER"
    sudo bash -c "cat << 'SUDO_EOF' > $SUDO_FILE
# VPS-ZSH-TAGBOARD
$TARGET_USER ALL=(ALL) NOPASSWD:ALL
SUDO_EOF"
    sudo chmod 0440 "$SUDO_FILE"

    # 设置 Zsh 为默认 Shell
    sudo chsh -s "$(which zsh)" "$TARGET_USER"

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
                read -p "请输入编号 (1-4): " CYCLE_OPT
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
    CPU_CORES=$(nproc)
    MEM_RAW=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
    if [ "$MEM_RAW" -lt 900 ]; then
        MEM_SIZE="${MEM_RAW}MB"
    else
        MEM_SIZE="$(( (MEM_RAW + 512) / 1024 ))GB"
    fi
    OS_NAME=$(grep "PRETTY_NAME" /etc/os-release | cut -d '"' -f 2 || uname -sr)

    TARGET_HOME=$(eval echo "~$TARGET_USER")

    # 生成 .zshrc（含备份）
    write_zshrc() {
        local home_dir=$1
        local zshrc="${home_dir}/.zshrc"
        local bak_date=$(date +%Y%m%d)
        local bak_file="${home_dir}/.zshrc.${bak_date}.bak"

        if [ -f "$zshrc" ] && [ ! -f "$bak_file" ]; then
            sudo cp "$zshrc" "$bak_file"
        fi

        sudo bash -c "cat << 'ZSHRC_EOF' > \"$zshrc\"
# VPS-ZSH-TAGBOARD
autoload -Uz compinit && compinit
setopt interactive_comments
zstyle ':completion:*' menu select
HISTSIZE=5000
SAVEHIST=5000
setopt SHARE_HISTORY
autoload -U up-line-or-beginning-search && zle -N up-line-or-beginning-search
bindkey \"^[[A\" up-line-or-beginning-search
bindkey \"^[[B\" down-line-or-beginning-search

if [[ -f /etc/os-release ]]; then
   OS_ID=\$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '\"')
fi
typeset -A colors
colors=(debian 125 ubuntu 202 kali 231 raspbian 125 pop 202 deepin 125 devuan 60 default 10)
MY_CLR=\${colors[\$OS_ID]:-\$colors[default]}
PROMPT=\"%F{\$MY_CLR}%n@%m%f:%F{blue}%~%f%# \"
ZSHRC_EOF"
    }

    write_zshrc "$TARGET_HOME"

    # 写入配置文件（安全方式）
    CONF_FILE="${TARGET_HOME}/.welcome.conf"
    {
        declare -p IN_P IN_L IN_N ADD_VAL SAFE_D START_M CPU_CORES MEM_SIZE OS_NAME
    } | sudo tee "$CONF_FILE" > /dev/null
    sudo chown "$TARGET_USER:$TARGET_USER" "$CONF_FILE"

    # 写欢迎看板脚本
    WELCOME_SH="${TARGET_HOME}/.welcome.sh"
    sudo bash -c "cat << 'WELCOME_EOF' > \"$WELCOME_SH\"
#!/bin/zsh
source ~/.welcome.conf

WHITE='\e[0;37m'
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\033[1;33m'
RESET='\e[0m'

if [ \"\$ADD_VAL\" = \"infinite\" ]; then
    DISP=\"\${WHITE}永久 (∞)\"
else
    ANCHOR_D=\$SAFE_D
    ADD_STR=\"\$ADD_VAL\"
    INIT_M=\$START_M
    INIT_Y=\$(date +%Y)

    NOW_TS=\$(date +%s)
    LAST_D_INIT=\$(date -d \"\$INIT_Y-\$INIT_M-01 +1 month -1 day\" +%d)
    [ \"\$ANCHOR_D\" -gt \"\$LAST_D_INIT\" ] && ACT_D=\$LAST_D_INIT || ACT_D=\$ANCHOR_D
    TARGET_TS=\$(date -d \"\$INIT_Y-\$INIT_M-\$ACT_D 23:59:59\" +%s)

    LOOP_GUARD=0
    while [ \"\$TARGET_TS\" -lt \"\$NOW_TS\" ] && [ \"\$LOOP_GUARD\" -lt 100 ]; do
        CUR_Y=\$(date -d \"@\$TARGET_TS\" +%Y)
        CUR_M=\$(date -d \"@\$TARGET_TS\" +%m)
        NEXT_BASE_Y=\$(date -d \"\$CUR_Y-\$CUR_M-01 + \$ADD_STR\" +%Y)
        NEXT_BASE_M=\$(date -d \"\$CUR_Y-\$CUR_M-01 + \$ADD_STR\" +%m)
        LAST_D_NEXT=\$(date -d \"\$NEXT_BASE_Y-\$NEXT_BASE_M-01 +1 month -1 day\" +%d)
        [ \"\$ANCHOR_D\" -gt \"\$LAST_D_NEXT\" ] && ACT_D=\$LAST_D_NEXT || ACT_D=\$ANCHOR_D
        TARGET_TS=\$(date -d \"\$NEXT_BASE_Y-\$NEXT_BASE_M-\$ACT_D 23:59:59\" +%s)
        ((LOOP_GUARD++))
    done

    EXP_DATE=\$(date -d \"@\$TARGET_TS\" +%Y-%m-%d)
    TODAY_ZERO=\$(date -d \"\$(date +%Y-%m-%d) 00:00:00\" +%s)
    DAYS_LEFT=\$(( (TARGET_TS - TODAY_ZERO) / 86400 ))

    if [ \"\$DAYS_LEFT\" -lt 0 ]; then
        DISP=\"\${RED}配置异常 (✘﹏✘)\"
    elif [ \"\$DAYS_LEFT\" -eq 0 ]; then
        DISP=\"\${YELLOW}到期啦，就是今天！(๑•̀ㅂ•́)و✧\"
    else
        if [ \"\$DAYS_LEFT\" -le 7 ]; then
            DISP=\"\${WHITE}\$EXP_DATE \${RED}(\${DAYS_LEFT}d)\"
        else
            DISP=\"\${WHITE}\$EXP_DATE (\${DAYS_LEFT}d)\"
        fi
    fi
fi

TAGS=\"\"
for val in \"\$IN_P\" \"\$IN_L\" \"\$IN_N\"; do
    [ -n \"\$val\" ] && TAGS=\"\$TAGS • \$val\"
done

echo \"\"
echo -e \"\${WHITE}[\$OS_NAME] \${CPU_CORES}C/\${MEM_SIZE}\${RESET}\"
echo -e \"\${WHITE}到期: \$DISP\${WHITE}\$TAGS \${RESET}\"
echo \"\"
WELCOME_EOF"

    sudo chmod +x "$WELCOME_SH"

    # 创建 .zprofile 自动加载
    ZPROFILE="${TARGET_HOME}/.zprofile"
    sudo bash -c "cat << 'ZPROFILE_EOF' > \"$ZPROFILE\"
[[ -f ~/.zshrc ]] && source ~/.zshrc
[[ -f ~/.welcome.sh ]] && zsh ~/.welcome.sh
ZPROFILE_EOF"

    # 统一修正权限
    sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"

    echo -e "\n\e[1;32m状态: 配置完成！\e[0m"
    echo "------------------------------------------------"
    echo "1. 立即切换环境: exec su - $TARGET_USER"
    [ "$IS_NEW_USER" = true ] && echo "2. 新用户设置密码: sudo passwd $TARGET_USER"
    echo "备份提示: 原始 .zshrc 已备份至 ~/.zshrc.XXXXXXXX.bak"
    echo "------------------------------------------------"
}

# 仅移除看板
do_remove_welcome() {
    while true; do
        read -re -p "请输入目标用户名 (默认 '$REAL_USER'): " TARGET_USER
        TARGET_USER="${TARGET_USER:-$REAL_USER}"
        if [ "$TARGET_USER" = "root" ]; then
            echo -e "\e[1;31m安全限制：禁止对 root 执行此操作，请重新输入。\e[0m"
            continue
        fi
        break
    done

    TARGET_HOME=$(eval echo "~$TARGET_USER")
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
    while true; do
        read -re -p "请输入要卸载的目标用户名 (默认 '$REAL_USER'): " TARGET_USER
        TARGET_USER="${TARGET_USER:-$REAL_USER}"
        if [ "$TARGET_USER" = "root" ]; then
            echo -e "\e[1;31m安全限制：禁止对 root 执行此操作，请重新输入。\e[0m"
            continue
        fi
        break
    done

    echo -e "\n\e[1;31m警告：即将对用户 $TARGET_USER 执行彻底卸载！\e[0m"
    echo "操作包括："
    echo "  - 将默认 Shell 还原为 /bin/bash"
    echo "  - 删除看板文件 (~/.welcome.sh, ~/.welcome.conf, ~/.zprofile)"
    echo "  - 移除 sudo 免密配置 (/etc/sudoers.d/$TARGET_USER)"
    echo "  - (可选) 彻底移除 Zsh 包"
    read -re -p "确认继续？(y/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "已取消。"
        return
    fi

    # 还原 Shell
    if command -v chsh &>/dev/null; then
        sudo chsh -s /bin/bash "$TARGET_USER" || echo "警告: 还原 Shell 失败，请手动执行 chsh -s /bin/bash $TARGET_USER"
    else
        echo "未找到 chsh 命令，跳过 Shell 还原。"
    fi

    # 移除看板文件
    TARGET_HOME=$(eval echo "~$TARGET_USER")
    sudo rm -f "$TARGET_HOME/.welcome.sh" "$TARGET_HOME/.welcome.conf" "$TARGET_HOME/.zprofile"

    # 移除 sudo 免密配置
    SUDO_FILE="/etc/sudoers.d/$TARGET_USER"
    if [ -f "$SUDO_FILE" ]; then
        sudo rm -f "$SUDO_FILE"
        echo "已移除 sudo 免密配置。"
    fi

    # 询问是否移除 Zsh 包
    read -re -p "是否彻底移除 Zsh 软件包？(y/N): " PURGE_ZSH
    if [[ "$PURGE_ZSH" =~ ^[Yy]$ ]]; then
        sudo apt remove --purge zsh -y
        sudo apt autoremove --purge -y
        echo "Zsh 包已移除。"
    fi

    echo -e "\e[1;32m卸载完成。请手动检查 .zshrc 是否需要删除（如不再使用 Zsh）。\e[0m"
}

# ---------- 主菜单（简洁等列版） ----------
echo "==================================="
echo "    看板管理脚本"
echo "==================================="
echo "  1) 安装看板"
echo "  2) 移除看板"
echo "  3) 彻底卸载"
echo "==================================="
read -re -p "请输入编号 (1-3，默认1): " MENU_OPT
MENU_OPT="${MENU_OPT:-1}"

case "$MENU_OPT" in
    1) do_install ;;
    2) do_remove_welcome ;;
    3) do_uninstall ;;
    *) echo "无效选项，退出。"; exit 1 ;;
esac