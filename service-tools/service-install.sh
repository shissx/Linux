#!/bin/bash
clear
echo "========================================"
echo "   Systemd 服务安装生成器（智能终极版）"
echo "========================================"

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
    if [ ! -f "$START_FILE_FULL" ]; then echo "❌ 启动文件不存在"; exit 1; fi
    if [ ! -x "$PYTHON_PATH" ]; then echo "❌ Python 不可用"; exit 1; fi

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
    sleep 1
    STATUS=$(sudo systemctl is-active "$SERVICE_NAME")
    if [[ "$STATUS" == "active" ]]; then
        echo "🎉 服务启动成功！状态：active"
    else
        echo "❌ 服务启动失败！"
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

# 工作目录
DEFAULT_PWD=$(pwd)
read -p "工作目录 (默认: $DEFAULT_PWD): " WORK_DIR
WORK_DIR=${WORK_DIR:-$DEFAULT_PWD}

# 启动文件（智能检测 shebang）
while true; do
    read -p "启动文件 (如: app.py / wb.py): " START_FILE
    if [ -n "$START_FILE" ]; then break; fi
    echo "❌ 不能为空！"
done
if [[ "$START_FILE" != /* ]]; then
    START_FILE_FULL="$WORK_DIR/$START_FILE"
else
    START_FILE_FULL="$START_FILE"
fi
if [ ! -f "$START_FILE_FULL" ]; then
    echo "❌ 文件不存在"
    exit 1
fi

# 智能检测 Python 解释器
SHEBANG=$(head -1 "$START_FILE_FULL" 2>/dev/null | grep '^#!' | sed 's/^#!//' | awk '{print $1}')
if [ -n "$SHEBANG" ] && [ -x "$SHEBANG" ]; then
    PYTHON_PATH="$SHEBANG"
    echo -e "\n✅ 从脚本 shebang 检测到 Python: $PYTHON_PATH"
else
    PYTHON_PATH=$(which python3)
    echo -e "\n✅ 使用系统 Python: $PYTHON_PATH"
fi

EXEC_PATH="$PYTHON_PATH $START_FILE_FULL"
echo "✅ 执行路径：$EXEC_PATH"

# 依赖路径
DEFAULT_MOUNT=$(dirname "$WORK_DIR")
read -p "依赖挂载路径 (默认: $DEFAULT_MOUNT): " MOUNT_PATH
MOUNT_PATH=${MOUNT_PATH:-$DEFAULT_MOUNT}

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
sudo systemd-analyze verify "$SERVICE_FILE" 2>/dev/null

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
sleep 1
STATUS=$(sudo systemctl is-active "$SERVICE_NAME")
if [[ "$STATUS" == "active" ]]; then
    echo -e "\n🎉 服务启动成功！"
else
    echo -e "\n❌ 启动失败"
fi