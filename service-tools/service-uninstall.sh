#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

# 配置变量 - 修改这里来改变筛选路径
TARGET_PATH="/vol1/1000"

# 卸载服务的函数
uninstall_service() {
    local service=$1
    echo -e "\n正在卸载：$service"
    
    # 停止服务
    if sudo systemctl stop "$service" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} 服务已停止"
    else
        echo -e "  ${YELLOW}⚠${NC}  服务停止失败（可能未运行）"
    fi
    
    # 禁用服务
    if sudo systemctl disable "$service" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} 服务已禁用"
    else
        echo -e "  ${YELLOW}⚠${NC}  服务禁用失败"
    fi
    
    # 删除服务文件
    local removed=0
    if [ -f "/etc/systemd/system/$service" ]; then
        sudo rm -f "/etc/systemd/system/$service"
        removed=1
        echo -e "  ${GREEN}✓${NC} 删除 /etc/systemd/system/$service"
    fi
    if [ -f "/usr/lib/systemd/system/$service" ]; then
        sudo rm -f "/usr/lib/systemd/system/$service"
        removed=1
        echo -e "  ${GREEN}✓${NC} 删除 /usr/lib/systemd/system/$service"
    fi
    
    if [ $removed -eq 0 ]; then
        echo -e "  ${YELLOW}⚠${NC}  未找到服务文件"
    fi
    
    # 重新加载 systemd
    sudo systemctl daemon-reload
    
    # 保留配置文件，只做提示（不删除）
    local conf_file="./${service%.service}.conf"
    if [ -f "$conf_file" ]; then
        echo -e "  ${YELLOW}📄${NC} 配置文件已保留：$conf_file"
        echo -e "  ${YELLOW}💡${NC} 如需重新安装，可直接使用该配置文件"
    fi
    
    echo -e "${GREEN}✅ 服务 $service 已成功卸载！${NC}"
}

# 清屏
clear

# 显示标题
echo -e "${YELLOW}=============================================${NC}"
echo -e "${GREEN}        服务卸载管理菜单${NC}"
echo -e "${YELLOW}=============================================${NC}"
echo -e "筛选规则：仅工作目录在 ${RED}${TARGET_PATH}/*${NC} 下的服务\n"

# 创建临时文件
TMP_FILE=$(mktemp)

echo -e "正在扫描服务..."

# 批量获取服务信息（优化版）
sudo systemctl list-units --type=service --all --no-legend 2>/dev/null | \
    awk '{print $1}' | \
    grep -v '^$' | \
    xargs -r -P 4 sudo systemctl show --property=Id,WorkingDirectory 2>/dev/null | \
    awk -v target="$TARGET_PATH" -v RS='' '
        $0 ~ "WorkingDirectory=" target "/" {
            id = ""
            workdir = ""
            for(i=1;i<=NF;i++) {
                if($i ~ /^Id=/) {
                    split($i, a, "=")
                    id = a[2]
                }
                if($i ~ /^WorkingDirectory=/) {
                    split($i, a, "=")
                    workdir = a[2]
                }
            }
            if(id && workdir) {
                print id "|" workdir
            }
        }
    ' | sort -u > "$TMP_FILE"

# 检查是否有服务
if [ ! -s "$TMP_FILE" ]; then
    echo -e "\n${RED}❌ 未找到符合条件的服务！${NC}"
    echo -e "提示：服务的工作目录需要在 ${RED}${TARGET_PATH}/${NC} 下"
    rm -f "$TMP_FILE"
    exit 0
fi

# 读取服务列表
SERVICE_LIST=()
while IFS='|' read -r service workdir; do
    SERVICE_LIST+=("$service:$workdir")
done < "$TMP_FILE"
rm -f "$TMP_FILE"

# 显示服务列表
echo -e "\n${GREEN}✅ 找到以下可卸载服务：${NC}"
echo "---------------------------------------------"
for i in "${!SERVICE_LIST[@]}"; do
    IFS=':' read -r service workdir <<< "${SERVICE_LIST[$i]}"
    echo -e "$((i+1)) - ${GREEN}$service${NC} | 目录：${workdir}"
done
echo "---------------------------------------------"
echo -e "0 - ${RED}退出${NC}\n"

# 获取用户输入
while true; do
    read -p "请选择（序号/0）：" CHOICE
    
    # 退出
    if [[ "$CHOICE" == "0" ]]; then
        echo -e "${GREEN}已退出${NC}"
        exit 0
    fi
    
    # 单个卸载
    if [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
        idx=$((CHOICE-1))
        if [[ $idx -ge 0 && $idx -lt ${#SERVICE_LIST[@]} ]]; then
            IFS=':' read -r service workdir <<< "${SERVICE_LIST[$idx]}"
            echo -e "\n准备卸载服务：${GREEN}$service${NC}"
            echo -e "工作目录：${workdir}"
            read -p "确认卸载？(y/N): " CONFIRM
            if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
                uninstall_service "$service"
                exit 0
            else
                echo -e "${GREEN}已取消${NC}"
                exit 0
            fi
        fi
    fi
    
    echo -e "${RED}❌ 输入无效，请重新选择！${NC}"
done
