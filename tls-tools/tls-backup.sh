#!/bin/bash

# 配置
CADDY_SSL_DIR="/etc/ssl/caddy"
BACKUP_DIR="/vol1/1000/caddy"
DOMAIN="www.lygf2016.com"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/caddy-certs-${DATE}.tar.gz"
LOG_FILE="${BACKUP_DIR}/backup.log"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "开始打包证书..."

# 检查证书文件
if [ ! -f "${CADDY_SSL_DIR}/${DOMAIN}.pem" ]; then
    log "错误: 证书文件不存在 ${CADDY_SSL_DIR}/${DOMAIN}.pem"
    exit 1
fi

if [ ! -f "${CADDY_SSL_DIR}/${DOMAIN}.key" ]; then
    log "错误: 私钥文件不存在 ${CADDY_SSL_DIR}/${DOMAIN}.key"
    exit 1
fi

# 打包证书
tar -czf "${BACKUP_FILE}" -C "${CADDY_SSL_DIR}" "${DOMAIN}.pem" "${DOMAIN}.key"

if [ $? -eq 0 ]; then
    log "打包成功: ${BACKUP_FILE}"
    log "文件大小: $(du -h ${BACKUP_FILE} | cut -f1)"
    
    # 清理30天前的旧备份
    find "${BACKUP_DIR}" -name "caddy-certs-*.tar.gz" -mtime +30 -delete
    log "已清理30天前的旧备份"
else
    log "打包失败"
    exit 1
fi