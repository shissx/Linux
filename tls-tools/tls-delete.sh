#!/bin/bash

# ============================================
# 删除 Caddy 证书并智能恢复脚本
# 功能：删除证书后，询问是更新证书还是恢复备份
# ============================================

DOMAIN="www.lygf2016.com"
CADDY_SSL_DIR="/etc/ssl/caddy"
BACKUP_DIR="/vol1/1000/caddy"
UPDATE_SCRIPT="/vol1/1000/caddy/tls-update.sh"
LOG_FILE="/var/log/caddy-cert-remove.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 检查证书是否存在
check_cert_exists() {
    if [ -f "$CADDY_SSL_DIR/${DOMAIN}.pem" ] && [ -f "$CADDY_SSL_DIR/${DOMAIN}.key" ]; then
        return 0
    else
        return 1
    fi
}

# 备份当前证书
backup_cert() {
    if check_cert_exists; then
        BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
        BACKUP_FILE="$BACKUP_DIR/caddy-certs-removed-${BACKUP_DATE}.tar.gz"
        mkdir -p "$BACKUP_DIR"
        tar -czf "$BACKUP_FILE" -C "$CADDY_SSL_DIR" "${DOMAIN}.pem" "${DOMAIN}.key" 2>/dev/null
        if [ $? -eq 0 ]; then
            log "${GREEN}✓ 已备份证书: $BACKUP_FILE${NC}"
            echo "$BACKUP_FILE"
            return 0
        fi
    fi
    return 1
}

# 恢复最新备份
restore_backup() {
    log "尝试恢复最新备份..."
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/caddy-certs-removed-*.tar.gz 2>/dev/null | head -1)
    
    if [ -z "$LATEST_BACKUP" ]; then
        log "${RED}✗ 未找到备份文件${NC}"
        return 1
    fi
    
    tar -xzf "$LATEST_BACKUP" -C "$CADDY_SSL_DIR/"
    chown caddy:caddy "$CADDY_SSL_DIR/${DOMAIN}.pem" "$CADDY_SSL_DIR/${DOMAIN}.key" 2>/dev/null
    chmod 644 "$CADDY_SSL_DIR/${DOMAIN}.pem"
    chmod 600 "$CADDY_SSL_DIR/${DOMAIN}.key"
    
    log "${GREEN}✓ 已从备份恢复: $LATEST_BACKUP${NC}"
    return 0
}

# 启动 Caddy
start_caddy() {
    if systemctl is-active --quiet caddy; then
        log "Caddy 已在运行中"
        return 0
    fi
    
    systemctl start caddy
    sleep 2
    
    if systemctl is-active --quiet caddy; then
        log "${GREEN}✓ Caddy 已启动${NC}"
        return 0
    else
        log "${RED}✗ Caddy 启动失败${NC}"
        return 1
    fi
}

# 停止 Caddy
stop_caddy() {
    if systemctl is-active --quiet caddy; then
        systemctl stop caddy
        log "${GREEN}✓ Caddy 已停止${NC}"
    fi
}

# 删除证书
remove_cert() {
    stop_caddy
    
    BACKUP_FILE=$(backup_cert)
    
    rm -f "$CADDY_SSL_DIR/${DOMAIN}.pem"
    rm -f "$CADDY_SSL_DIR/${DOMAIN}.key"
    
    if [ ! -f "$CADDY_SSL_DIR/${DOMAIN}.pem" ] && [ ! -f "$CADDY_SSL_DIR/${DOMAIN}.key" ]; then
        log "${GREEN}✓ 证书已删除${NC}"
        return 0
    else
        log "${RED}✗ 证书删除失败${NC}"
        return 1
    fi
}

# 调用更新脚本
run_update_script() {
    if [ -f "$UPDATE_SCRIPT" ]; then
        log "正在执行证书更新脚本: $UPDATE_SCRIPT"
        bash "$UPDATE_SCRIPT"
        return $?
    else
        log "${RED}✗ 更新脚本不存在: $UPDATE_SCRIPT${NC}"
        return 1
    fi
}

# 交互式菜单（证书存在时）
menu_cert_exists() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Caddy 证书管理 - 证书当前存在${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo "1. 查看证书信息"
    echo "2. 删除证书（删除后需手动处理）"
    echo "3. 直接调用证书更新脚本"
    echo "4. 退出"
    echo "=========================================="
    read -p "请选择 [1-4]: " choice
    
    case $choice in
        1)
            echo ""
            echo "证书信息："
            openssl x509 -in "$CADDY_SSL_DIR/${DOMAIN}.pem" -noout -subject -issuer -dates 2>/dev/null
            echo ""
            menu_cert_exists
            ;;
        2)
            confirm_delete
            ;;
        3)
            run_update_script
            ;;
        4)
            echo "退出"
            exit 0
            ;;
        *)
            echo "无效选择"
            menu_cert_exists
            ;;
    esac
}

# 交互式菜单（证书不存在时）
menu_cert_missing() {
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  ⚠ 警告：Caddy 证书不存在！${NC}"
    echo -e "${RED}  Caddy 无法正常启动 HTTPS 服务${NC}"
    echo -e "${RED}========================================${NC}"
    echo "1. 调用证书更新脚本（从飞牛获取新证书）"
    echo "2. 从备份恢复证书"
    echo "3. 查看可用备份"
    echo "4. 退出（Caddy 服务将停止）"
    echo "=========================================="
    read -p "请选择 [1-4]: " choice
    
    case $choice in
        1)
            run_update_script
            ;;
        2)
            restore_backup
            if check_cert_exists; then
                start_caddy
            fi
            ;;
        3)
            echo ""
            echo "可用备份列表："
            ls -lh "$BACKUP_DIR"/caddy-certs-removed-*.tar.gz 2>/dev/null || echo "无备份文件"
            echo ""
            menu_cert_missing
            ;;
        4)
            echo "退出，Caddy 服务将保持停止状态"
            exit 0
            ;;
        *)
            echo "无效选择"
            menu_cert_missing
            ;;
    esac
}

# 确认删除
confirm_delete() {
    echo ""
    echo -e "${RED}警告：即将删除 Caddy 证书文件！${NC}"
    echo "删除后将无法提供 HTTPS 服务，直到证书恢复或更新"
    echo ""
    echo "1. 删除并退出（手动处理）"
    echo "2. 删除并立即调用更新脚本"
    echo "3. 返回主菜单"
    echo "=========================================="
    read -p "请选择 [1-3]: " delete_choice
    
    case $delete_choice in
        1)
            remove_cert
            echo ""
            echo -e "${YELLOW}证书已删除。运行以下命令恢复：${NC}"
            echo "  $0 --restore"
            echo "或手动调用更新脚本："
            echo "  $UPDATE_SCRIPT"
            exit 0
            ;;
        2)
            remove_cert
            run_update_script
            ;;
        3)
            menu_cert_exists
            ;;
        *)
            echo "无效选择"
            confirm_delete
            ;;
    esac
}

# 强制恢复模式
force_restore() {
    echo "强制恢复模式..."
    restore_backup
    start_caddy
    exit 0
}

# 强制删除模式
force_remove() {
    remove_cert
    exit $?
}

# 主函数
main() {
    case "$1" in
        --restore|-r)
            force_restore
            ;;
        --update|-u)
            run_update_script
            exit $?
            ;;
        --force|-f)
            force_remove
            ;;
        *)
            if check_cert_exists; then
                menu_cert_exists
            else
                menu_cert_missing
            fi
            ;;
    esac
}

main "$1"