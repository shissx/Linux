#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear

echo -e "${YELLOW}=============================================${NC}"
echo -e "${GREEN}        服务卸载管理菜单${NC}"
echo -e "${YELLOW}=============================================${NC}"
echo -e "筛选规则：仅工作目录在 /vol1/1000/* 下的服务\n"

SERVICE_LIST=()
rm -f /tmp/service_uninstall_list.tmp

sudo systemctl list-units --all --type=service | while read line; do
    service=$(echo "$line" | awk '{print $1}')
    if [[ $service == *".service" ]]; then
        workdir=$(sudo systemctl show "$service" -p WorkingDirectory 2>/dev/null | cut -d= -f2)
        if [[ $workdir == /vol1/1000/* ]]; then
            echo "$service|$workdir" >> /tmp/service_uninstall_list.tmp
        fi
    fi
done

if [ ! -s /tmp/service_uninstall_list.tmp ]; then
    echo -e "${RED}未找到符合条件的服务！${NC}"
    rm -f /tmp/service_uninstall_list.tmp
    exit 0
fi

while IFS='|' read -r srv wd; do
    SERVICE_LIST+=("$srv:$wd")
done < /tmp/service_uninstall_list.tmp
rm -f /tmp/service_uninstall_list.tmp

echo -e "${GREEN}找到以下可卸载服务：${NC}"
echo "---------------------------------------------"
for i in "${!SERVICE_LIST[@]}"; do
    IFS=':' read -r srv wd <<< "${SERVICE_LIST[$i]}"
    echo -e "$((i+1)) - ${YELLOW}$srv${NC} | 目录：$wd"
done
echo "---------------------------------------------"
echo -e "0 - 退出\n"

read -p "请选择：" CHOICE

uninstall_svc() {
    local s=$1
    echo -e "\n${YELLOW}处理服务：$s${NC}"
    sudo systemctl stop "$s" 2>/dev/null
    sudo systemctl disable "$s" 2>/dev/null
    sudo rm -f /etc/systemd/system/"$s" /usr/lib/systemd/system/"$s" 2>/dev/null
    sudo systemctl daemon-reload
    echo -e "${GREEN}✅ 服务已卸载：$s${NC}"
}

if [[ $CHOICE == "0" ]]; then
    echo -e "${GREEN}已退出${NC}"
    exit 0
fi

if [[ $CHOICE =~ ^[0-9]+$ ]]; then
    idx=$((CHOICE-1))
    if [[ $idx -ge 0 && $idx -lt ${#SERVICE_LIST[@]} ]]; then
        IFS=':' read -r s w <<< "${SERVICE_LIST[$idx]}"
        uninstall_svc "$s"
    else
        echo -e "${RED}无效序号${NC}"
    fi
    exit 0
fi

echo -e "${RED}输入无效${NC}"