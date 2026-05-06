#!/bin/bash

# ============================================
# 自动检测并更新 Caddy 证书脚本
# 功能：检测飞牛最新证书，如有更新则自动部署到 Caddy
# ============================================

# 配置变量
DOMAIN="www.lygf2016.com"
FNOS_SSL_BASE="/usr/trim/var/trim_connect/ssls/$DOMAIN"
CADDY_SSL_DIR="/etc/ssl/caddy"
BACKUP_DIR="/vol1/1000/caddy"
LOG_FILE="/var/log/caddy-cert-auto-update.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_success() {
    log "${GREEN}✓ $1${NC}"
}

log_error() {
    log "${RED}✗ $1${NC}"
}

log_info() {
    log "${YELLOW}ℹ $1${NC}"
}

# 检查必要目录
check_directories() {
    if [ ! -d "$FNOS_SSL_BASE" ]; then
        log_error "飞牛证书目录不存在: $FNOS_SSL_BASE"
        exit 1
    fi
    
    if [ ! -d "$CADDY_SSL_DIR" ]; then
        log_error "Caddy证书目录不存在: $CADDY_SSL_DIR"
        exit 1
    fi
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_info "备份目录不存在，正在创建..."
        mkdir -p "$BACKUP_DIR"
    fi
}

# 获取飞牛最新证书目录
get_latest_fnos_cert() {
    LATEST_DIR=$(ls -d "$FNOS_SSL_BASE"/*/ 2>/dev/null | sort -r | head -1)
    
    if [ -z "$LATEST_DIR" ]; then
        log_error "未找到任何证书目录"
        exit 1
    fi
    
    FNOS_CERT="${LATEST_DIR}fullchain.crt"
    FNOS_KEY="${LATEST_DIR}${DOMAIN}.key"
    
    if [ ! -f "$FNOS_CERT" ] || [ ! -f "$FNOS_KEY" ]; then
        log_error "证书文件不完整: $FNOS_CERT 或 $FNOS_KEY"
        exit 1
    fi
    
    log_info "最新证书目录: $LATEST_DIR"
}

# 计算文件MD5
calculate_md5() {
    md5sum "$1" 2>/dev/null | cut -d' ' -f1
}

# 检查是否需要更新
need_update() {
    CADDY_CERT="$CADDY_SSL_DIR/${DOMAIN}.pem"
    
    if [ ! -f "$CADDY_CERT" ]; then
        log_info "Caddy证书不存在，需要部署"
        return 0  # 需要更新
    fi
    
    FNOS_MD5=$(calculate_md5 "$FNOS_CERT")
    CADDY_MD5=$(calculate_md5 "$CADDY_CERT")
    
    if [ "$FNOS_MD5" != "$CADDY_MD5" ]; then
        log_info "证书已更新 (MD5: $CADDY_MD5 -> $FNOS_MD5)"
        return 0  # 需要更新
    else
        log_info "证书无变化，无需更新"
        return 1  # 无需更新
    fi
}

# 备份当前证书
backup_current_cert() {
    CADDY_CERT="$CADDY_SSL_DIR/${DOMAIN}.pem"
    CADDY_KEY="$CADDY_SSL_DIR/${DOMAIN}.key"
    
    if [ -f "$CADDY_CERT" ] && [ -f "$CADDY_KEY" ]; then
        BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
        BACKUP_FILE="$BACKUP_DIR/caddy-certs-backup-${BACKUP_DATE}.tar.gz"
        
        tar -czf "$BACKUP_FILE" -C "$CADDY_SSL_DIR" "${DOMAIN}.pem" "${DOMAIN}.key" 2>/dev/null
        if [ $? -eq 0 ]; then
            log_success "已备份当前证书: $BACKUP_FILE"
            # 清理30天前的备份
            find "$BACKUP_DIR" -name "caddy-certs-backup-*.tar.gz" -mtime +30 -delete
        else
            log_error "备份失败"
        fi
    else
        log_info "无现有证书，跳过备份"
    fi
}

# 部署新证书
deploy_cert() {
    log_info "正在部署新证书..."
    
    # 复制证书文件
    cp "$FNOS_CERT" "$CADDY_SSL_DIR/${DOMAIN}.pem"
    cp "$FNOS_KEY" "$CADDY_SSL_DIR/${DOMAIN}.key"
    
    if [ $? -ne 0 ]; then
        log_error "复制证书失败"
        return 1
    fi
    
    # 设置正确的权限
    chown caddy:caddy "$CADDY_SSL_DIR/${DOMAIN}.pem" "$CADDY_SSL_DIR/${DOMAIN}.key"
    chmod 644 "$CADDY_SSL_DIR/${DOMAIN}.pem"
    chmod 600 "$CADDY_SSL_DIR/${DOMAIN}.key"
    
    log_success "证书文件已部署，权限已设置"
    return 0
}

# 验证证书有效性
verify_cert() {
    # 检查证书有效期
    EXPIRY_DATE=$(openssl x509 -in "$CADDY_SSL_DIR/${DOMAIN}.pem" -noout -enddate 2>/dev/null | cut -d= -f2)
    
    if [ -n "$EXPIRY_DATE" ]; then
        log_success "证书有效期至: $EXPIRY_DATE"
    else
        log_error "证书验证失败"
        return 1
    fi
    
    # 检查证书和私钥是否匹配
    CERT_MD5=$(openssl x509 -noout -modulus -in "$CADDY_SSL_DIR/${DOMAIN}.pem" 2>/dev/null | openssl md5)
    KEY_MD5=$(openssl rsa -noout -modulus -in "$CADDY_SSL_DIR/${DOMAIN}.key" 2>/dev/null | openssl md5)
    
    if [ "$CERT_MD5" = "$KEY_MD5" ]; then
        log_success "证书与私钥匹配"
        return 0
    else
        log_error "证书与私钥不匹配"
        return 1
    fi
}

# 重启Caddy
restart_caddy() {
    log_info "正在重启Caddy服务..."
    
    # 先测试配置
    if caddy validate --config /etc/caddy/Caddyfile 2>/dev/null; then
        systemctl restart caddy
        sleep 2
        
        if systemctl is-active --quiet caddy; then
            log_success "Caddy服务已成功重启"
            return 0
        else
            log_error "Caddy服务启动失败"
            return 1
        fi
    else
        log_error "Caddy配置文件验证失败"
        return 1
    fi
}

# 测试HTTPS连接
test_https() {
    log_info "测试HTTPS连接..."
    
    # 等待 Caddy 完全启动
    sleep 3
    
    if curl -k -s --connect-timeout 10 https://www.lygf2016.com:31168 > /dev/null 2>&1; then
        log_success "HTTPS连接测试成功"
        return 0
    else
        log_error "HTTPS连接测试失败"
        return 1
    fi
}

# 打包证书到指定目录（可选）
package_cert() {
    PACKAGE_FILE="$BACKUP_DIR/caddy-certs-$(date +%Y%m%d).tar.gz"
    tar -czf "$PACKAGE_FILE" -C "$CADDY_SSL_DIR" "${DOMAIN}.pem" "${DOMAIN}.key" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_success "证书打包完成: $PACKAGE_FILE"
    else
        log_error "证书打包失败"
    fi
}

# 主函数
main() {
    log "=========================================="
    log "开始自动检测并更新Caddy证书"
    log "=========================================="
    
    # 1. 检查目录
    check_directories
    
    # 2. 获取飞牛最新证书
    get_latest_fnos_cert
    
    # 3. 检查是否需要更新
    if need_update; then
        log_info "检测到新证书，开始部署..."
        
        # 4. 备份当前证书
        backup_current_cert
        
        # 5. 部署新证书
        if deploy_cert; then
            # 6. 验证证书
            if verify_cert; then
                # 7. 重启Caddy
                if restart_caddy; then
                    # 8. 测试HTTPS
                    test_https
                    # 9. 打包备份
                    package_cert
                    log_success "证书更新完成！"
                else
                    log_error "Caddy重启失败，尝试回滚..."
                    # 这里可以添加回滚逻辑
                    exit 1
                fi
            else
                log_error "证书验证失败"
                exit 1
            fi
        else
            log_error "证书部署失败"
            exit 1
        fi
    else
        log_info "无需更新"
    fi
    
    log "=========================================="
    log "脚本执行完成"
    log "=========================================="
}

# 执行主函数
main