#!/bin/bash
clear

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONF_FILE="shortcut.conf"
RC_FILE="$HOME/.bashrc"
[ -f "$HOME/.zshrc" ] && RC_FILE="$HOME/.zshrc"

# ========== 函数定义 ==========

# 显示菜单
show_menu() {
    clear
    echo -e "========================================"
    echo -e "      快捷命令管理器"
    echo -e "========================================"
    echo -e ""
    echo -e "  ${GREEN}1${NC}) 添加快捷命令（读取配置或扫描脚本）"
    echo -e "  ${GREEN}2${NC}) 查看已添加的快捷命令"
    echo -e "  ${GREEN}3${NC}) 查看 .bashrc 内容"
    echo -e "  ${GREEN}4${NC}) 编辑 .bashrc (nano)"
    echo -e "  ${GREEN}5${NC}) 重载 .bashrc"
    echo -e "  ${GREEN}6${NC}) 删除所有快捷命令"
    echo -e "  ${GREEN}7${NC}) 编辑配置文件 (shortcut.conf)"
    echo -e "  ${GREEN}0${NC}) 退出"
    echo -e ""
    echo -e "========================================"
}

# 添加快捷命令
add_shortcuts() {
    echo ""
    echo "========================================"
    echo "      添加快捷命令"
    echo "========================================"
    
    declare -A shortcuts
    need_save_conf=0
    
    if [ -f "$CONF_FILE" ]; then
        # 有配置文件，从配置文件读取
        echo -e "${GREEN}✅ 读取配置：$CONF_FILE${NC}"
        echo "----------------------------------------"
        
        # 计算最大命令名长度
        max_len=0
        while IFS= read -r line || [ -n "$line" ]; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            cmd=$(echo "$line" | awk '{print $1}')
            len=${#cmd}
            [ $len -gt $max_len ] && max_len=$len
        done < "$CONF_FILE"
        
        # 显示配置内容并存储
        while IFS= read -r line || [ -n "$line" ]; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            cmd=$(echo "$line" | awk '{print $1}')
            path=$(echo "$line" | cut -d' ' -f2-)
            printf "  %-${max_len}s %s\n" "$cmd" "$path"
            shortcuts[$cmd]="$path"
        done < "$CONF_FILE"
        echo "----------------------------------------"
        
    else
        # 没有配置文件，扫描当前目录所有 .sh 文件
        echo -e "${YELLOW}📂 未找到 $CONF_FILE，自动扫描 .sh 文件...${NC}"
        echo "----------------------------------------"
        
        sh_files=(*.sh)
        if [ ${#sh_files[@]} -eq 0 ] || [ "${sh_files[0]}" = "*.sh" ]; then
            echo -e "${RED}❌ 当前目录没有找到 .sh 文件${NC}"
            return 1
        fi
        
        # 计算最大文件名长度
        max_len=0
        for file in "${sh_files[@]}"; do
            cmd="${file%.sh}"
            len=${#cmd}
            [ $len -gt $max_len ] && max_len=$len
        done
        
        # 显示扫描结果并存储
        for file in "${sh_files[@]}"; do
            cmd="${file%.sh}"
            path="$(pwd)/$file"
            printf "  %-${max_len}s %s\n" "$cmd" "$path"
            shortcuts[$cmd]="$path"
        done
        echo "----------------------------------------"
        
        # 询问是否保存配置
        echo -e "\n${YELLOW}是否保存配置到 $CONF_FILE？${NC}"
        read -p "保存后可以手动编辑修改 (y/n): " save_conf
        if [[ "$save_conf" == "y" ]]; then
            need_save_conf=1
        fi
    fi
    
    # 检查是否有有效配置
    if [ ${#shortcuts[@]} -eq 0 ]; then
        echo -e "${RED}❌ 没有找到有效的配置${NC}"
        return 1
    fi
    
    # bash 保留关键字检查
    RESERVED_KEYWORDS="if then else elif fi case esac for in do done while until function select time"
    echo -e "\n${BLUE}🔍 检查命令名是否与 bash 关键字冲突...${NC}"
    has_error=0
    for c in "${!shortcuts[@]}"; do
        for keyword in $RESERVED_KEYWORDS; do
            if [ "$c" = "$keyword" ]; then
                echo -e "${RED}❌ 错误：'$c' 是 bash 保留关键字，不能用作别名${NC}"
                echo "   请使用其他名称"
                has_error=1
            fi
        done
    done
    
    if [ $has_error -eq 1 ]; then
        return 1
    fi
    echo -e "${GREEN}✅ 所有命令名检查通过${NC}"
    
    # 读取已存在的别名
    declare -A existing
    while IFS= read -r line; do
        if [[ $line =~ ^alias[[:space:]]+([^=]+)=\'(bash)[[:space:]]+(.+)\'$ ]]; then
            alias_name="${BASH_REMATCH[1]}"
            alias_value="${BASH_REMATCH[3]}"
            existing["$alias_name"]="$alias_value"
        fi
    done < "$RC_FILE"
    
    # 显示预览（去重）
    echo -e "\n${BLUE}📋 即将处理：${NC}"
    need_update=0
    declare -A final_shortcuts  # ← 确保在这里声明

    for c in "${!shortcuts[@]}"; do
        p="${shortcuts[$c]}"
        
        # 检查是否有重复路径
        duplicate=0
        for existing_c in "${!final_shortcuts[@]}"; do
            if [ "${final_shortcuts[$existing_c]}" = "$p" ]; then
                echo -e "  ${YELLOW}⚠️  路径重复：$c 和 $existing_c 指向同一文件${NC}"
                echo -e "      将使用：$existing_c"
                duplicate=1
                break
            fi
        done
        
        if [ $duplicate -eq 0 ]; then
            final_shortcuts[$c]="$p"
            if [[ -n "${existing[$c]}" && "${existing[$c]}" == "$p" ]]; then
                echo -e "  ${GREEN}✅ $c -> $p${NC}"
            else
                need_update=1
                echo -e "  ${YELLOW}🔄 $c -> $p${NC}"
                if [[ -n "${existing[$c]}" && "${existing[$c]}" != "$p" ]]; then
                    echo -e "      旧: ${existing[$c]}"
                fi
            fi
        fi
    done
    
    if [ $need_update -eq 0 ]; then
        echo -e "\n${GREEN}✨ 所有配置都已正确存在，无需修改${NC}"
        echo ""
        echo -e "${BLUE}📋 当前快捷命令：${NC}"
        for c in "${!final_shortcuts[@]}"; do
            printf "  %-15s -> %s\n" "$c" "${final_shortcuts[$c]}"
        done
        echo ""
        read -p "按回车键返回菜单..."
        return 0
    fi
    
    read -p "❌ 确认写入？(y/n): " confirm
    [[ "$confirm" != "y" ]] && echo "❌ 已取消" && return 0
    
    # 备份
    backup_file="$RC_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$RC_FILE" "$backup_file"
    echo -e "\n${GREEN}✅ 已备份到：$backup_file${NC}"
    
    # 清理旧的别名（只清理本工具添加的，通过标记识别）
    echo -e "${YELLOW}🧹 清理旧的别名...${NC}"
    # 删除所有带标记的快捷命令
    sed -i '/# SHORTCUT_MANAGER_START/,/# SHORTCUT_MANAGER_END/d' "$RC_FILE"
    
    # 写入新的别名（使用标记区域）
    echo -e "\n${BLUE}📝 写入命令...${NC}"
    echo "# SHORTCUT_MANAGER_START - Generated at $(date)" >> "$RC_FILE"
    for c in "${!final_shortcuts[@]}"; do
        p="${final_shortcuts[$c]}"
        escaped_path="${p//\'/\'\\\'\'}"
        echo "alias $c='bash $escaped_path'" >> "$RC_FILE"
    done
    echo "# SHORTCUT_MANAGER_END" >> "$RC_FILE"
    
    # 保存配置文件
    if [ $need_save_conf -eq 1 ]; then
        echo -e "\n${BLUE}📝 保存配置文件...${NC}"
        cat > "$CONF_FILE" << EOF
# 快捷命令配置文件
# 格式：命令名 脚本路径
# 生成时间：$(date)
# 可以手动编辑此文件来添加/修改快捷命令

EOF
        for c in "${!final_shortcuts[@]}"; do
            echo "$c ${final_shortcuts[$c]}" >> "$CONF_FILE"
        done
        echo -e "${GREEN}✅ 配置文件已保存：$CONF_FILE${NC}"
        echo -e "${YELLOW}💡 你可以用 nano $CONF_FILE 来编辑修改${NC}"
    fi
    
    # 生效
    source "$RC_FILE"
    
    echo -e "\n${GREEN}🎉 全部完成！${NC}"
    echo -e "${BLUE}📝 已写入 ${#final_shortcuts[@]} 个快捷命令${NC}"
    echo ""
    echo -e "${GREEN}📖 使用示例：${NC}"
    for c in "${!final_shortcuts[@]}"; do
        printf "  %-15s # 执行 %s\n" "$c" "${final_shortcuts[$c]}"
    done
}

# 查看已添加的快捷命令
view_shortcuts() {
    echo ""
    echo "========================================"
    echo "      已添加的快捷命令"
    echo "========================================"
    echo ""
    
    # 查找标记区域内的别名
    found=0
    in_section=0
    while IFS= read -r line; do
        if [[ "$line" == "# SHORTCUT_MANAGER_START"* ]]; then
            in_section=1
            echo -e "${BLUE}--- 本工具管理的快捷命令 ---${NC}"
            continue
        fi
        if [[ "$line" == "# SHORTCUT_MANAGER_END" ]]; then
            in_section=0
            break
        fi
        if [ $in_section -eq 1 ] && [[ "$line" =~ ^alias[[:space:]]+([^=]+)=\'bash[[:space:]]+(.+)\'$ ]]; then
            alias_name="${BASH_REMATCH[1]}"
            alias_path="${BASH_REMATCH[2]}"
            printf "  ${GREEN}%-15s${NC} -> %s\n" "$alias_name" "$alias_path"
            found=1
        fi
    done < "$RC_FILE"
    
    if [ $found -eq 0 ]; then
        echo -e "${YELLOW}  ⚠️  没有找到已添加的快捷命令${NC}"
    fi
    echo ""
    read -p "按回车键返回菜单..."
}

# 查看 .bashrc 内容
view_bashrc() {
    echo ""
    echo "========================================"
    echo "      .bashrc 内容"
    echo "========================================"
    echo ""
    
    if [ -f "$RC_FILE" ]; then
        if command -v less &> /dev/null; then
            less "$RC_FILE"
        else
            cat "$RC_FILE"
            echo ""
            read -p "按回车键继续..."
        fi
    else
        echo -e "${RED}❌ $RC_FILE 不存在${NC}"
        read -p "按回车键返回菜单..."
    fi
}

# 编辑 .bashrc
edit_bashrc() {
    echo ""
    echo "========================================"
    echo "      编辑 .bashrc"
    echo "========================================"
    echo ""
    
    if [ -f "$RC_FILE" ]; then
        backup_file="$RC_FILE.edit.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$RC_FILE" "$backup_file"
        echo -e "${GREEN}✅ 已自动备份到：$backup_file${NC}"
        echo ""
        read -p "按回车键开始编辑 (nano)..."
        
        nano "$RC_FILE"
        
        echo ""
        echo -e "${GREEN}✅ 编辑完成${NC}"
        echo -e "${YELLOW}💡 记得运行 [5] 重载 .bashrc 使更改生效${NC}"
    else
        echo -e "${RED}❌ $RC_FILE 不存在${NC}"
    fi
    echo ""
    read -p "按回车键返回菜单..."
}

# 编辑配置文件
edit_config() {
    echo ""
    echo "========================================"
    echo "      编辑配置文件"
    echo "========================================"
    echo ""
    
    if [ ! -f "$CONF_FILE" ]; then
        echo -e "${YELLOW}⚠️  配置文件不存在，将创建新文件${NC}"
        echo "# 快捷命令配置文件" > "$CONF_FILE"
        echo "# 格式：命令名 脚本路径" >> "$CONF_FILE"
        echo "# 示例：" >> "$CONF_FILE"
        echo "#   myapp /path/to/my/script.sh" >> "$CONF_FILE"
        echo "#   logs /var/log/app/logs.sh" >> "$CONF_FILE"
    fi
    
    backup_file="$CONF_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONF_FILE" "$backup_file"
    echo -e "${GREEN}✅ 已自动备份到：$backup_file${NC}"
    echo ""
    read -p "按回车键开始编辑 (nano)..."
    
    nano "$CONF_FILE"
    
    echo ""
    echo -e "${GREEN}✅ 编辑完成${NC}"
    echo -e "${YELLOW}💡 运行 [1] 添加快捷命令 来应用更改${NC}"
    echo ""
    read -p "按回车键返回菜单..."
}

# 重载 .bashrc
reload_bashrc() {
    echo ""
    echo "========================================"
    echo "      重载 .bashrc"
    echo "========================================"
    
    if [ -f "$RC_FILE" ]; then
        source "$RC_FILE"
        echo -e "${GREEN}✅ 已重载 $RC_FILE${NC}"
        echo ""
        echo -e "${BLUE}📋 当前快捷命令：${NC}"
        in_section=0
        while IFS= read -r line; do
            if [[ "$line" == "# SHORTCUT_MANAGER_START"* ]]; then
                in_section=1
                continue
            fi
            if [[ "$line" == "# SHORTCUT_MANAGER_END" ]]; then
                in_section=0
                continue
            fi
            if [ $in_section -eq 1 ] && [[ "$line" =~ ^alias[[:space:]]+([^=]+)=\'bash[[:space:]]+(.+)\'$ ]]; then
                printf "  ${GREEN}%-15s${NC} -> %s\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
            fi
        done < "$RC_FILE"
    else
        echo -e "${RED}❌ $RC_FILE 不存在${NC}"
    fi
    echo ""
    read -p "按回车键返回菜单..."
}

# 删除所有快捷命令
delete_all_shortcuts() {
    echo ""
    echo "========================================"
    echo "      删除所有快捷命令"
    echo "========================================"
    echo ""
    echo -e "${RED}⚠️  警告：这将删除所有由本工具添加的快捷命令${NC}"
    echo ""
    read -p "确认删除？(y/n): " confirm
    [[ "$confirm" != "y" ]] && echo "❌ 已取消" && return
    
    # 备份
    backup_file="$RC_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$RC_FILE" "$backup_file"
    echo -e "${GREEN}✅ 已备份到：$backup_file${NC}"
    
    # 删除标记区域
    echo -e "${YELLOW}🧹 删除快捷命令...${NC}"
    sed -i '/# SHORTCUT_MANAGER_START/,/# SHORTCUT_MANAGER_END/d' "$RC_FILE"
    
    # 重载
    source "$RC_FILE"
    
    echo -e "${GREEN}✅ 已删除所有快捷命令${NC}"
    echo ""
    read -p "按回车键返回菜单..."
}

# ========== 主程序 ==========
while true; do
    show_menu
    read -p "请选择 [0-7]: " choice
    
    case $choice in
        1) add_shortcuts
           view_shortcuts ;;
        2) view_shortcuts ;;
        3) view_bashrc ;;
        4) edit_bashrc ;;
        5) reload_bashrc ;;
        6) delete_all_shortcuts ;;
        7) edit_config ;;
        0) echo -e "${GREEN}退出${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ 无效选择${NC}"; sleep 1 ;;
    esac
done