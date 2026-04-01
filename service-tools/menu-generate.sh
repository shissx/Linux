#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 收集信息
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   服务管理菜单生成器${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

read -p "服务名称 (如: cc-website): " SERVICE_NAME
read -p "菜单标题 (如: 选择题查重系统): " MENU_TITLE
read -p "输出脚本文件名 (如: manage-cc.sh): " OUTPUT_FILE

# 校验必填项
if [ -z "$SERVICE_NAME" ] || [ -z "$OUTPUT_FILE" ]; then
    echo -e "${RED}错误: 服务名称和输出文件名不能为空${NC}"
    exit 1
fi

# 生成管理菜单脚本（关键修复：去掉EOF的单引号，让变量正常解析）
cat > "$OUTPUT_FILE" << EOF
#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 服务配置
SERVICE_NAME="$SERVICE_NAME"
MOUNT_PATH=\$(sudo systemctl cat \$SERVICE_NAME 2>/dev/null | grep RequiresMountsFor | cut -d= -f2)

# 显示菜单
show_menu() {
    clear
    echo -e "\${CYAN}====================================\${NC}"
    echo -e "\${GREEN}  $MENU_TITLE\${NC}"
    echo -e "\${CYAN}====================================\${NC}"
    echo ""
    echo -e "\${YELLOW}【基础操作】\${NC}"
    echo "1. 启动服务"
    echo "2. 停止服务"
    echo "3. 重启服务"
    echo ""
    echo -e "\${YELLOW}【状态监控】\${NC}"
    echo "4. 查看状态"
    echo "5. 查看日志"
    echo ""
    echo -e "\${YELLOW}【开机管理】\${NC}"
    echo "6. 设置开机自启"
    echo "7. 取消开机自启"
    echo "8. 查看自启状态"
    echo ""
    echo -e "\${YELLOW}【可靠性保障】\${NC}"
    echo "9. 查看挂载依赖"
    echo "10. 查看重启策略"
    echo ""
    echo -e "\${RED}0. 退出\${NC}"
    echo -e "\${CYAN}====================================\${NC}"
    echo ""
}

# 1. 启动服务
start_service() {
    echo -e "\${BLUE}正在启动 \$SERVICE_NAME...\${NC}"
    sudo systemctl start \$SERVICE_NAME
    if [ \$? -eq 0 ]; then
        echo -e "\${GREEN}✅ 启动成功\${NC}"
    else
        echo -e "\${RED}❌ 启动失败\${NC}"
        echo -e "\${YELLOW}建议查看日志: journalctl -u \$SERVICE_NAME -n 20\${NC}"
    fi
}

# 2. 停止服务
stop_service() {
    echo -e "\${BLUE}正在停止 \$SERVICE_NAME...\${NC}"
    sudo systemctl stop \$SERVICE_NAME
    if [ \$? -eq 0 ]; then
        echo -e "\${GREEN}✅ 已停止\${NC}"
    else
        echo -e "\${RED}❌ 停止失败\${NC}"
    fi
}

# 3. 重启服务
restart_service() {
    echo -e "\${BLUE}正在重启 \$SERVICE_NAME...\${NC}"
    sudo systemctl restart \$SERVICE_NAME
    if [ \$? -eq 0 ]; then
        echo -e "\${GREEN}✅ 重启成功\${NC}"
    else
        echo -e "\${RED}❌ 重启失败\${NC}"
    fi
}

# 4. 查看状态
show_status() {
    echo -e "\${BLUE}服务状态:\${NC}"
    sudo systemctl status \$SERVICE_NAME --no-pager -l
}

# 5. 查看日志
view_log() {
    echo -e "\${BLUE}最近30行日志:\${NC}"
    sudo journalctl -u \$SERVICE_NAME -n 30 --no-pager
    
    echo ""
    echo -e "\${YELLOW}是否实时跟踪日志? (y/n): \${NC}"
    read -r follow
    if [[ \$follow == "y" || \$follow == "Y" ]]; then
        echo -e "\${BLUE}实时日志跟踪 (Ctrl+C 退出):\${NC}"
        sudo journalctl -u \$SERVICE_NAME -f
    fi
}

# 6. 设置开机自启
enable_autostart() {
    echo -e "\${BLUE}设置 \$SERVICE_NAME 开机自启...\${NC}"
    sudo systemctl enable \$SERVICE_NAME
    if [ \$? -eq 0 ]; then
        echo -e "\${GREEN}✅ 已设置开机自启\${NC}"
    else
        echo -e "\${RED}❌ 设置失败\${NC}"
    fi
}

# 7. 取消开机自启
disable_autostart() {
    echo -e "\${BLUE}取消 \$SERVICE_NAME 开机自启...\${NC}"
    sudo systemctl disable \$SERVICE_NAME
    if [ \$? -eq 0 ]; then
        echo -e "\${GREEN}✅ 已取消开机自启\${NC}"
    else
        echo -e "\${RED}❌ 取消失败\${NC}"
    fi
}

# 8. 查看自启状态
show_autostart_status() {
    echo -e "\${BLUE}开机自启状态:\${NC}"
    sudo systemctl is-enabled \$SERVICE_NAME 2>/dev/null && echo "✅ enabled (已启用)" || echo "❌ disabled (未启用)"
}

# 9. 查看挂载依赖
show_mount_dependency() {
    echo -e "\${BLUE}=== 挂载依赖检查 ===\${NC}"
    echo ""
    
    # 查看配置
    echo -e "\${YELLOW}【配置】\${NC}"
    sudo systemctl cat \$SERVICE_NAME 2>/dev/null | grep -E "RequiresMountsFor|After" || echo "未配置挂载依赖"
    echo ""
    
    # 检查目录
    if [ -n "\$MOUNT_PATH" ]; then
        echo -e "\${YELLOW}【当前挂载状态】\${NC}"
        if [ -d "\$MOUNT_PATH" ]; then
            echo -e "\${GREEN}✅ 目录已挂载: \$MOUNT_PATH\${NC}"
            ls -ld "\$MOUNT_PATH"
        else
            echo -e "\${RED}❌ 目录未挂载: \$MOUNT_PATH\${NC}"
        fi
        echo ""
    fi
    
    # 查看启动顺序
    echo -e "\${YELLOW}【启动顺序】\${NC}"
    systemd-analyze critical-chain \$SERVICE_NAME.service 2>/dev/null | head -10 || echo "无法获取启动顺序"
    echo ""
    
    echo -e "\${YELLOW}【说明】\${NC}"
    echo "- RequiresMountsFor: systemd自动等待目录挂载"
    echo "- 目录未挂载时，服务不会启动"
    echo "- 挂载完成后自动启动服务"
}

# 10. 查看重启策略
show_restart_policy() {
    echo -e "\${BLUE}=== 重启策略检查 ===\${NC}"
    echo ""
    
    # 查看配置
    echo -e "\${YELLOW}【配置】\${NC}"
    sudo systemctl cat \$SERVICE_NAME 2>/dev/null | grep -E "Restart|RestartSec" || echo "未找到重启配置"
    echo ""
    
    # 获取当前PID
    CURRENT_PID=\$(sudo systemctl show -p MainPID \$SERVICE_NAME 2>/dev/null | cut -d= -f2)
    echo -e "\${YELLOW}【当前进程】\${NC}"
    echo "Main PID: \$CURRENT_PID"
    echo ""
    
    # 查看重启记录
    echo -e "\${YELLOW}【最近重启记录】\${NC}"
    sudo journalctl -u \$SERVICE_NAME --since "1 hour ago" --grep="Started\|Stopped\|restart" --no-pager | tail -5 || echo "无重启记录"
    echo ""
    
    echo -e "\${YELLOW}【说明】\${NC}"
    echo "- Restart=always: 进程意外退出时自动重启"
    echo "- RestartSec=30: 退出后等待30秒再启动"
    echo ""
    echo -e "\${YELLOW}【测试方法】\${NC}"
    echo "手动杀死进程测试自动重启:"
    echo "sudo kill -9 \\\$(sudo systemctl show -p MainPID \$SERVICE_NAME | cut -d= -f2)"
    echo "等待30秒后查看: sudo systemctl status \$SERVICE_NAME"
}

# 主循环
while true; do
    show_menu
    read -p "请选择 [0-10]: " choice
    
    case \$choice in
        1) start_service ;;
        2) stop_service ;;
        3) restart_service ;;
        4) show_status ;;
        5) view_log ;;
        6) enable_autostart ;;
        7) disable_autostart ;;
        8) show_autostart_status ;;
        9) show_mount_dependency ;;
        10) show_restart_policy ;;
        0) 
            echo -e "\${GREEN}再见！\${NC}"
            exit 0
            ;;
        *)
            echo -e "\${RED}无效选择\${NC}"
            ;;
    esac
    
    echo ""
    read -p "按回车键继续..."
done
EOF

# 添加执行权限
chmod +x "$OUTPUT_FILE"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ 管理菜单生成成功！${NC}"
echo -e "${GREEN}文件: $OUTPUT_FILE${NC}"
echo -e "${GREEN}运行: ./$OUTPUT_FILE${NC}"
echo -e "${GREEN}========================================${NC}"