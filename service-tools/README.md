# Service Tools - 服务管理工具集

## 📖 简介

用于管理和部署 systemd 服务的工具集，专为 `/vol1/1000` 目录下的服务设计。提供服务的安装、卸载、管理菜单生成等功能。

## 📁 工具列表

| 工具 | 说明           | 用途                       |
| ------ | ---------------- | ---------------------------- |
| `service-install.sh`     | 服务安装器     | 创建和安装 systemd 服务    |
| `service-uninstall.sh`     | 服务卸载器     | 卸载已安装的 systemd 服务  |
| `menu-generate.sh`     | 菜单生成器     | 为指定服务生成管理菜单脚本 |
| `wb.sh`     | Web 服务管理   | wb 服务的管理菜单（示例）  |
| `shortcut.sh`     | 快捷命令管理器 | 管理 shell 别名快捷命令    |

---

# 特别说明

可以先 `shortcut.sh` 生成快捷命令，便于快速测试。

```bash
./shortcut.sh
```

## 🚀 快速开始

### 1. 安装服务

```bash
./service-install.sh
```

**功能**：

- 从配置文件加载服务参数（支持 `.conf` 文件）
- 手动创建服务（交互式输入）
- 自动检测 Python 解释器
- 自动处理服务覆盖（如已存在会提示）

**服务配置项**：

- 服务名称、描述
- 运行用户/组
- 工作目录
- 启动文件
- 依赖挂载路径

### 2. 卸载服务

```bash
./service-uninstall.sh
```

**功能**：

- 扫描 `/vol1/1000` 下可管理的服务
- 停止并禁用服务
- 删除服务文件
- 保留配置文件供重新安装使用

### 3. 生成服务管理菜单

```bash
./menu-generate.sh
```

**功能**：

- 扫描并选择要管理的服务
- 生成专属管理菜单脚本
- 自动识别服务的工作目录和挂载依赖

**生成的菜单功能**：

```text
1. 启动服务
2. 停止服务
3. 重启服务
4. 查看状态
5. 查看日志
6. 开机自启
7. 取消自启
8. 自启状态
9. 挂载依赖
10. 重启策略
0. 退出
```

### 4. 管理快捷命令

```bash
./shortcut.sh
```

**功能**：

- 扫描当前目录的 `.sh` 文件生成别名
- 支持配置文件 `shortcut.conf` 自定义命令
- 自动写入 `~/.bashrc`
- 提供菜单式管理（查看、编辑、删除、重载）

---

## 📋 使用示例

### 安装服务

```bash
# 1. 准备配置文件（可选）
cat > wb.conf << EOF
SERVICE_NAME="wb.service"
SERVICE_DESC="wb 服务"
RUN_USER="xuehai"
RUN_GROUP="Users"
WORK_DIR="/vol1/1000/xuehai/shell/service-tools"
EXEC_PATH="/usr/bin/python3 /vol1/1000/xuehai/shell/service-tools/wb.py"
MOUNT_PATH="/vol1/1000/xuehai/shell"
EOF

# 2. 运行安装脚本
./service-install.sh
# 选择配置文件序号或手动输入
```

### 卸载服务

```bash
./service-uninstall.sh
# 选择要卸载的服务序号，确认即可
```

### 生成管理菜单

```bash
./menu-generate.sh
# 选择服务（如 wb.service）
# 输入菜单标题（可选）
# 生成管理脚本，例如 manage-wb.sh
```

### 使用管理菜单

```bash
# 查看服务状态
./manage-wb.sh
# 选择 4 查看状态

# 测试自动重启
./manage-wb.sh
# 选择 10 → y → 自动杀死进程并验证重启
```

### 添加快捷命令

```bash
./shortcut.sh
# 选择 1 → 自动扫描或从配置文件读取 → 确认写入
# 执行 source ~/.bashrc 使别名生效

# 使用别名
caz  # 安装服务
cxz  # 卸载服务
ccd  # 服务管理菜单
ckj  # 快捷命令管理
cwb  # wb 服务管理
```

---

## 🔧 配置文件格式

### 服务配置文件 (`*.conf`)

```bash
SERVICE_NAME="myapp.service"           # 服务名称
SERVICE_DESC="My Application"          # 服务描述
RUN_USER="xuehai"                      # 运行用户
RUN_GROUP="Users"                      # 运行组
WORK_DIR="/path/to/work"               # 工作目录
EXEC_PATH="/usr/bin/python3 app.py"    # 执行命令
MOUNT_PATH="/vol1/1000"                # 依赖挂载路径
PYTHON_PATH="/usr/bin/python3"         # Python 解释器（可选）
```

### 快捷命令配置文件 (`shortcut.conf`)

```conf
myapp /path/to/myapp.sh
logs /var/log/logs.sh
status /path/to/status.sh
```

格式：`命令名 脚本路径`

---

## 🎯 服务管理菜单功能详解

| 功能     | 说明                       |
| ---------- | ---------------------------- |
| 启动服务 | `systemctl start`                           |
| 停止服务 | `systemctl stop`                           |
| 重启服务 | `systemctl restart`                           |
| 查看状态 | 显示服务详细状态           |
| 查看日志 | 显示最近日志，支持实时跟踪 |
| 开机自启 | `systemctl enable`                           |
| 取消自启 | `systemctl disable`                           |
| 自启状态 | 查看是否开机启动           |
| 挂载依赖 | 检查 `RequiresMountsFor` 配置                 |
| 重启策略 | 显示配置并支持自动重启测试 |

---

## ⚙️ 环境要求

- Linux 系统（支持 systemd）
- Bash 4.0+
- sudo 权限

---

## 📝 注意事项

1. **服务工作目录**：服务的工作目录必须在 `/vol1/1000` 下才会被扫描到
2. **配置文件保留**：卸载服务时不会删除 `.conf` 配置文件，便于重新安装
3. **换行符问题**：如遇 `^M` 错误，请用 `sed -i 's/\r$//' *.sh` 转换
4. **Git 换行符**：建议设置 `git config core.autocrlf false` 避免自动转换

---

## 🛠️ 常见问题

### Q: 服务启动失败怎么办？

```bash
# 查看日志
journalctl -u 服务名 -n 50
# 检查配置
systemctl cat 服务名
```

### Q: 如何查看服务的挂载依赖？

使用管理菜单的选项 9，会显示 `RequiresMountsFor` 配置和挂载状态。

### Q: 如何测试自动重启？

使用管理菜单的选项 10，选择 y 会自动杀死进程并验证重启。

### Q: 快捷命令不生效？

```bash
source ~/.bashrc
# 或重新登录
```

## 📄 许可证

内部工具，仅供内部使用。