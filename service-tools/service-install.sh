#!/bin/bash
clear
echo "========================================"
echo "   Systemd 服务安装生成器（智能终极版）"
echo "========================================"

# ==============================
# 检查是否有 sudo 权限
# ==============================
if [ "$EUID" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
    echo "❌ 需要 sudo 权限来安装服务"
    exit 1
fi

# ==============================
# 扫描配置文件菜单（带输入校验）
# ==============================
CONF_FILES=($(ls *.conf 2>/dev/null | sort))
echo "📂 检测到配置文件："
if [ ${#CONF_FILES[@]} -eq 0 ]; then
    echo "   无配置文件"
else
    for i in "${!CONF_FILES[@]}"; do
        echo "$((i+1)) - ${CONF_FILES[$i]}"
    done
fi
echo "0 - 手动创建服务"
echo

while true; do
    read -p "请选择（序号/0）：" CONF_CHOICE
    if [[ "$CONF_CHOICE" =~ ^[0-9]+$ ]]; then
        if [[ $CONF_CHOICE -eq 0 || ( $CONF_CHOICE -ge 1 && $CONF_CHOICE -le ${#CONF_FILES[@]} ) ]]; then
            break
        fi
    fi
    echo "❌ 输入无效，请输入正确序号！"
done

# ==============================
# 加载配置 + 验证 + 服务覆盖判断
# ==============================
if [[ $CONF_CHOICE -ge 1 ]]; then
    CONF_FILE="${CONF_FILES[$((CONF_CHOICE-1))]}"
    echo "✅ 加载配置：$CONF_FILE"
    source "$CONF_FILE"

    echo -e "\n========================================"
    echo "🔍 正在验证配置信息..."
    echo "========================================"

    if [ -z "$SERVICE_NAME" ]; then echo "❌ 服务名称为空"; exit 1; fi
    if ! id -u "$RUN_USER" >/dev/null 2>&1; then echo "❌ 用户不存在"; exit 1; fi
    if ! getent group "$RUN_GROUP" >/dev/null 2>&1; then echo "❌ 组不存在"; exit 1; fi
    if [ ! -d "$WORK_DIR" ]; then echo "❌ 工作目录不存在"; exit 1; fi
    START_FILE_FULL=$(echo "$EXEC_PATH" | awk '{print $NF}')
    if [ ! -f "$START_FILE_FULL" ]; then 
        echo "❌ 启动文件不存在: $START_FILE_FULL"
        exit 1
    fi
    # 只有定义了 PYTHON_PATH 才验证（兼容旧配置文件）
    if [ -n "$PYTHON_PATH" ] && [ ! -x "$PYTHON_PATH" ]; then 
        echo "❌ Python 不可用: $PYTHON_PATH"
        exit 1
    fi

    echo "✅ 配置验证通过！"
    echo -e "\n========================================"
    echo "📌 配置信息"
    echo "========================================"
    echo "服务名称：$SERVICE_NAME"
    echo "服务描述：$SERVICE_DESC"
    echo "运行用户：$RUN_USER"
    echo "运行组：$RUN_GROUP"
    echo "工作目录：$WORK_DIR"
    echo "执行路径：$EXEC_PATH"
    echo "依赖路径：$MOUNT_PATH"
    echo "========================================"

    # ==============================
    # ✅ 新增：服务已存在 → 提示覆盖
    # ==============================
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
    if [ -f "$SERVICE_FILE" ]; then
        echo -e "\n⚠️  服务已存在：$SERVICE_NAME"
        read -p "是否停止并重建服务？(y/n): " REPLACE_SERVICE
        if [[ "$REPLACE_SERVICE" != "y" ]]; then
            echo "❌ 已取消"
            exit 0
        fi

        echo "⏳ 停止旧服务..."
        sudo systemctl stop "$SERVICE_NAME" 2>/dev/null
        sudo systemctl disable "$SERVICE_NAME" 2>/dev/null
        sudo rm -f "$SERVICE_FILE"
        echo "✅ 旧服务已清理"
    fi

    read -p "确认创建服务？(y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" ]]; then echo "❌ 已取消"; exit 0; fi

    # 创建服务
    echo -e "\n正在生成服务：$SERVICE_NAME"
    sudo tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=$SERVICE_DESC
After=network.target
RequiresMountsFor=$MOUNT_PATH

[Service]
User=$RUN_USER
Group=$RUN_GROUP
WorkingDirectory=$WORK_DIR
ExecStart=$EXEC_PATH
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"
    
    # 智能等待服务启动
    echo "⏳ 等待服务启动..."
    STATUS="inactive"
    for i in {1..10}; do
        sleep 1
        STATUS=$(sudo systemctl is-active "$SERVICE_NAME" 2>/dev/null)
        if [[ "$STATUS" == "active" ]]; then
            break
        fi
    done
    
    if [[ "$STATUS" == "active" ]]; then
        echo "🎉 服务启动成功！状态：active"
    else
        echo "❌ 服务启动失败！当前状态：$STATUS"
    fi
    exit 0
fi

# ==============================
# 0 = 手动创建
# ==============================

while true; do
    read -p "服务名称 (如: myapp): " SERVICE_NAME
    if [ -n "$SERVICE_NAME" ]; then break; fi
    echo "❌ 服务名称不能为空！"
done

read -p "服务描述 (可回车省略): " SERVICE_DESC
if [ -z "$SERVICE_DESC" ]; then SERVICE_DESC="$SERVICE_NAME 服务"; fi

# 用户选择
CURRENT_USER=$(whoami)
echo -e "\n=== 选择运行用户（默认当前: $CURRENT_USER）==="
USER_LIST=($(getent passwd | grep -E "/bin/bash|/bin/sh" | cut -d: -f1 | sort | head -10))
UNIQUE_USERS=($CURRENT_USER)
for u in "${USER_LIST[@]}"; do
    if [[ "$u" != "$CURRENT_USER" ]]; then UNIQUE_USERS+=("$u"); fi
done
for i in "${!UNIQUE_USERS[@]}"; do
    mark=""
    if [[ "${UNIQUE_USERS[$i]}" == "$CURRENT_USER" ]]; then mark="✅"; fi
    echo "$((i+1)) $mark ${UNIQUE_USERS[$i]}"
done
while true; do
    read -p "请选择用户序号 [默认1]: " USER_CHOICE
    USER_CHOICE=${USER_CHOICE:-1}
    if [[ "$USER_CHOICE" =~ ^[0-9]+$ && $USER_CHOICE -ge 1 && $USER_CHOICE -le ${#UNIQUE_USERS[@]} ]]; then
        break
    fi
    echo "❌ 输入无效！"
done
RUN_USER=${UNIQUE_USERS[$((USER_CHOICE-1))]}
echo "✅ 选择用户: $RUN_USER"

# 组选择
echo -e "\n=== 选择运行组 ==="
FIXED_GROUPS=("Users" "users" "root" "Administrators")
for i in "${!FIXED_GROUPS[@]}"; do
    mark=""
    if [ $i -eq 0 ]; then mark="(默认)"; fi
    echo "$((i+1)) ${FIXED_GROUPS[$i]} $mark"
done
while true; do
    read -p "请选择组序号 [默认1]: " GROUP_CHOICE
    GROUP_CHOICE=${GROUP_CHOICE:-1}
    if [[ "$GROUP_CHOICE" =~ ^[0-9]+$ && $GROUP_CHOICE -ge 1 && $GROUP_CHOICE -le 4 ]]; then
        break
    fi
    echo "❌ 输入无效！"
done
RUN_GROUP=${FIXED_GROUPS[$((GROUP_CHOICE-1))]}
echo "✅ 选择组: $RUN_GROUP"

# 工作目录（带存在性验证）
DEFAULT_PWD=$(pwd)
while true; do
    read -p "工作目录 (默认: $DEFAULT_PWD): " WORK_DIR
    WORK_DIR=${WORK_DIR:-$DEFAULT_PWD}
    if [ -d "$WORK_DIR" ]; then
        break
    else
        echo "❌ 目录不存在: $WORK_DIR"
        echo "请重新输入..."
    fi
done

# 询问是否需要参数
echo -e "\n程序参数？"
echo "1) 无参数（自动组合命令）"
echo "2) 有参数（手动输入完整命令）"
while true; do
    read -p "请选择 [1-2]: " HAS_ARGS
    if [[ "$HAS_ARGS" =~ ^[1-2]$ ]]; then
        break
    fi
    echo "❌ 请输入 1 或 2"
done

# 如果有参数，直接输入完整命令
if [ "$HAS_ARGS" -eq 2 ]; then
    echo -e "\n⚠️  程序需要参数，请直接输入完整命令"
    while true; do
        read -p "完整命令 (如: /usr/bin/python3 /path/to/app.py --port 8080): " EXEC_PATH
        if [ -n "$EXEC_PATH" ]; then
            CMD_PATH=$(echo "$EXEC_PATH" | awk '{print $1}')
            if [ -x "$CMD_PATH" ] || command -v "$CMD_PATH" >/dev/null 2>&1; then
                break
            else
                echo "⚠️  警告: $CMD_PATH 可能不可执行"
                read -p "仍然继续？(y/n): " CONTINUE
                if [[ "$CONTINUE" == "y" ]]; then
                    break
                fi
            fi
        else
            echo "❌ 命令不能为空"
        fi
    done
    echo "✅ 执行方式：自定义命令（带参数）"
    echo "✅ 最终执行路径：$EXEC_PATH"
    
    # 跳过后续，直接进入依赖路径
else
    # 无参数：自动扫描可执行文件
    echo -e "\n📂 扫描工作目录中的可执行文件："
    SCAN_FILES=()
    
    # 查找可执行文件
    while IFS= read -r file; do
        SCAN_FILES+=("$file")
    done < <(find "$WORK_DIR" -maxdepth 1 -type f \( -perm -111 -o -name "*.py" -o -name "*.sh" -o -name "*.bash" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.pl" -o -name "*.rb" \) 2>/dev/null | sort)
    
    if [ ${#SCAN_FILES[@]} -gt 0 ]; then
        echo "找到以下文件："
        for i in "${!SCAN_FILES[@]}"; do
            filename=$(basename "${SCAN_FILES[$i]}")
            if [ -x "${SCAN_FILES[$i]}" ]; then
                type="可执行"
            elif [[ "${SCAN_FILES[$i]}" == *.py ]]; then
                type="Python"
            elif [[ "${SCAN_FILES[$i]}" == *.sh ]] || [[ "${SCAN_FILES[$i]}" == *.bash ]]; then
                type="Shell"
            elif [[ "${SCAN_FILES[$i]}" == *.js ]]; then
                type="JavaScript"
            elif [[ "${SCAN_FILES[$i]}" == *.ts ]]; then
                type="TypeScript"
            elif [[ "${SCAN_FILES[$i]}" == *.go ]]; then
                type="Go"
            else
                type="脚本"
            fi
            echo "$((i+1)) - $filename ($type)"
        done
        echo "0 - 手动输入"
    else
        echo "未找到可执行文件或脚本文件，将使用手动输入"
    fi
    
    # 启动文件输入（无参数情况）
    while true; do
        if [ ${#SCAN_FILES[@]} -gt 0 ]; then
            read -p "请选择文件序号（0手动输入）: " FILE_CHOICE
            if [[ "$FILE_CHOICE" =~ ^[0-9]+$ ]]; then
                if [ "$FILE_CHOICE" -eq 0 ]; then
                    read -p "启动文件 (如: app.py / myapp): " START_FILE
                    if [ -n "$START_FILE" ]; then 
                        if [[ "$START_FILE" != /* ]]; then
                            START_FILE_FULL="$WORK_DIR/$START_FILE"
                        else
                            START_FILE_FULL="$START_FILE"
                        fi
                        if [ -f "$START_FILE_FULL" ]; then
                            break
                        else
                            echo "❌ 文件不存在: $START_FILE_FULL"
                        fi
                    else
                        echo "❌ 不能为空！"
                    fi
                elif [ "$FILE_CHOICE" -ge 1 ] && [ "$FILE_CHOICE" -le ${#SCAN_FILES[@]} ]; then
                    START_FILE_FULL="${SCAN_FILES[$((FILE_CHOICE-1))]}"
                    START_FILE=$(basename "$START_FILE_FULL")
                    echo "✅ 已选择: $START_FILE"
                    break
                else
                    echo "❌ 输入无效，请输入正确序号！"
                fi
            else
                echo "❌ 请输入数字！"
            fi
        else
            read -p "启动文件 (如: app.py / myapp): " START_FILE
            if [ -n "$START_FILE" ]; then 
                if [[ "$START_FILE" != /* ]]; then
                    START_FILE_FULL="$WORK_DIR/$START_FILE"
                else
                    START_FILE_FULL="$START_FILE"
                fi
                if [ -f "$START_FILE_FULL" ]; then
                    break
                else
                    echo "❌ 文件不存在: $START_FILE_FULL"
                fi
            else
                echo "❌ 不能为空！"
            fi
        fi
    done
    
    # 选择执行方式（仅两种）
    echo -e "\n请选择执行方式（自动添加可执行权限）："
    echo "1) 直接执行文件"
    echo "2) Python 程序（自动检测 shebang 或使用系统 Python）"
    
    while true; do
        read -p "请选择 [1-2]: " EXEC_TYPE
        if [[ "$EXEC_TYPE" =~ ^[1-2]$ ]]; then
            break
        fi
        echo "❌ 请输入 1 或 2"
    done
    
    # 初始化 PYTHON_PATH 变量
    PYTHON_PATH=""
    
    # 确保启动文件有执行权限
    if [ ! -x "$START_FILE_FULL" ]; then
        chmod +x "$START_FILE_FULL"
        echo "✅ 已添加可执行权限: $START_FILE_FULL"
    else
        echo "✅ 文件已有执行权限: $START_FILE_FULL"
    fi
    
    case $EXEC_TYPE in
        1)
            EXEC_PATH="$START_FILE_FULL"
            echo "✅ 执行方式：直接执行"
            ;;
        2)
            SHEBANG=$(head -1 "$START_FILE_FULL" 2>/dev/null | grep '^#!' | sed 's/^#!//' | awk '{print $1}')
            if [ -n "$SHEBANG" ] && [ -x "$SHEBANG" ]; then
                PYTHON_PATH="$SHEBANG"
                echo -e "\n✅ 从脚本 shebang 检测到 Python: $PYTHON_PATH"
            else
                PYTHON_PATH=$(which python3)
                if [ -z "$PYTHON_PATH" ]; then
                    echo "❌ 未找到 python3"
                    exit 1
                fi
                echo -e "\n✅ 使用系统 Python: $PYTHON_PATH"
            fi
            EXEC_PATH="$PYTHON_PATH $START_FILE_FULL"
            echo "✅ 执行路径：$EXEC_PATH"
            ;;
    esac
    
    echo "✅ 最终执行路径：$EXEC_PATH"
fi

# 依赖挂载路径（带存在性验证）
DEFAULT_MOUNT=$(dirname "$WORK_DIR")
while true; do
    read -p "依赖挂载路径 (默认: $DEFAULT_MOUNT): " MOUNT_PATH
    MOUNT_PATH=${MOUNT_PATH:-$DEFAULT_MOUNT}
    if [ -d "$MOUNT_PATH" ]; then
        break
    else
        echo "❌ 路径不存在: $MOUNT_PATH"
        echo "请重新输入..."
    fi
done

# 确认
echo -e "\n========================================"
echo "📌 确认信息"
echo "========================================"
echo "服务：$SERVICE_NAME"
echo "描述：$SERVICE_DESC"
echo "用户：$RUN_USER"
echo "组：$RUN_GROUP"
echo "目录：$WORK_DIR"
echo "执行：$EXEC_PATH"
echo "依赖：$MOUNT_PATH"
echo "========================================"
while true; do
    read -p "创建？(y/n): " CONFIRM
    [[ "$CONFIRM" =~ ^[yn]$ ]] && break
    echo "❌ 输入 y/n"
done
if [[ "$CONFIRM" != "y" ]]; then echo "❌ 取消"; exit 0; fi

# ==============================
# 服务已存在 → 覆盖提示
# ==============================
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
if [ -f "$SERVICE_FILE" ]; then
    echo -e "\n⚠️  服务已存在"
    read -p "停止并重建？(y/n): " REPLACE_SERVICE
    if [[ "$REPLACE_SERVICE" != "y" ]]; then echo "❌ 取消"; exit 0; fi
    sudo systemctl stop "$SERVICE_NAME" 2>/dev/null
    sudo systemctl disable "$SERVICE_NAME" 2>/dev/null
    sudo rm -f "$SERVICE_FILE"
    echo "✅ 旧服务已清理"
fi

# 创建服务
sudo tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=$SERVICE_DESC
After=network.target
RequiresMountsFor=$MOUNT_PATH

[Service]
User=$RUN_USER
Group=$RUN_GROUP
WorkingDirectory=$WORK_DIR
ExecStart=$EXEC_PATH
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

echo "✅ 服务创建成功"
# 验证服务文件，显示详细输出
if sudo systemd-analyze verify "$SERVICE_FILE" 2>&1; then
    echo "✅ 服务文件验证通过"
else
    echo "⚠️  服务文件验证有警告，但将继续"
fi

# ==============================
# 配置文件覆盖提示（手动+配置都触发）
# ==============================
CONF_PATH="./$SERVICE_NAME.conf"
if [ -f "$CONF_PATH" ]; then
    echo -e "\n⚠️  配置文件已存在：$CONF_PATH"
    while true; do
        echo "1 覆盖"
        echo "2 重命名"
        echo "0 不保存"
        read -p "选择：" CONF_OPT
        case $CONF_OPT in
            1) echo "✅ 覆盖"; break ;;
            2) read -p "新名称：" NEW_NAME
               CONF_PATH="./$NEW_NAME.conf"
               echo "✅ 新配置：$CONF_PATH"
               break ;;
            0) CONF_PATH=""; echo "✅ 不保存"; break ;;
            *) echo "❌ 无效" ;;
        esac
    done
fi

if [ -n "$CONF_PATH" ]; then
    # 确保 PYTHON_PATH 变量存在（兼容非 Python 服务）
    if [ -z "$PYTHON_PATH" ]; then
        PYTHON_PATH=""
    fi
    cat > "$CONF_PATH" <<EOF
SERVICE_NAME="$SERVICE_NAME"
SERVICE_DESC="$SERVICE_DESC"
RUN_USER="$RUN_USER"
RUN_GROUP="$RUN_GROUP"
WORK_DIR="$WORK_DIR"
EXEC_PATH="$EXEC_PATH"
MOUNT_PATH="$MOUNT_PATH"
PYTHON_PATH="$PYTHON_PATH"
EOF
    echo "✅ 配置已保存：$CONF_PATH"
fi

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

# 智能等待服务启动
echo "⏳ 等待服务启动..."
STATUS="inactive"
for i in {1..10}; do
    sleep 1
    STATUS=$(sudo systemctl is-active "$SERVICE_NAME" 2>/dev/null)
    if [[ "$STATUS" == "active" ]]; then
        break
    fi
done

if [[ "$STATUS" == "active" ]]; then
    echo -e "\n🎉 服务启动成功！"
else
    echo -e "\n❌ 启动失败，当前状态：$STATUS"
    echo "提示：可使用 'sudo systemctl status $SERVICE_NAME' 查看详细信息"
fi