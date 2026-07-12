---
name: postgresql-setup
description: Install, configure PostgreSQL for remote access, and create database users on a fresh environment. Use when the user wants to "install PostgreSQL", "setup postgres", "add a postgres user", or "configure remote database access".
---

# PostgreSQL Setup Skill

一站式 PostgreSQL 安装、远程访问配置和用户管理。覆盖从零安装到远程连接验证的完整流程，适用于 Ubuntu/Debian 新环境初始化。

## 触发条件

- 用户要求"安装 PostgreSQL"、"初始化 PostgreSQL 环境"
- 用户要求"创建数据库用户"、"添加 PostgreSQL 用户"
- 用户要求"配置 PostgreSQL 远程连接"
- 用户提到需要本地工具远程连接到服务器 PostgreSQL

## 工作流

### 阶段 1：环境检查

先确认系统信息和当前 PostgreSQL 状态：

```bash
cat /etc/os-release | head -3
which psql 2>/dev/null && psql --version || echo "未安装"
pg_lsclusters 2>/dev/null || true
```

如果平台不是 Ubuntu/Debian，参考 [references/other-platforms.md](references/other-platforms.md)。

### 阶段 2：安装 PostgreSQL

对于未安装的环境，执行安装。使用 `scripts/install_postgresql.sh` 或手动执行：

```bash
sudo apt update -qq
sudo apt install -y postgresql postgresql-contrib
```

安装后验证服务运行：

```bash
sudo systemctl status postgresql --no-pager | head -5
psql --version
```

> **注意：** 安装完成后会自动创建 `postgres` 超管用户（仅限本地 peer 认证登录，无密码）。

### 阶段 3：配置远程访问

需要修改两个配置文件。

#### 3a. `postgresql.conf` — 监听所有网络接口

找到配置文件路径：

```bash
PG_CONF=$(sudo find /etc/postgresql -name postgresql.conf 2>/dev/null | head -1)
```

修改监听地址：

```bash
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"
```

验证：

```bash
sudo grep "^listen_addresses" "$PG_CONF"
# 输出应为: listen_addresses = '*'
```

#### 3b. `pg_hba.conf` — 添加远程认证规则

```bash
PG_HBA=$(dirname "$PG_CONF")/pg_hba.conf
```

添加用户远程访问规则。需要传入用户名和数据库名。默认使用 `scram-sha-256` 认证（PostgreSQL 13+）：

```bash
# 示例: 允许 myuser 从任何 IP 连接到 mydb
echo "host    mydb    myuser    0.0.0.0/0    scram-sha-256" | sudo tee -a "$PG_HBA"
```

> **安全建议：** 生产环境将 `0.0.0.0/0` 替换为特定 IP 段，如 `192.168.1.0/24`。

### 阶段 4：创建用户和数据库

使用 `scripts/create_pg_user.sh` 脚本，或手动执行：

```bash
# 设置 postgres 超管密码
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '超管密码';"

# 创建用户
sudo -u postgres psql -c "CREATE USER 用户名 WITH PASSWORD '用户密码';"

# 创建专属数据库
sudo -u postgres psql -c "CREATE DATABASE 数据库名 OWNER 用户名;"

# 授予权限
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE 数据库名 TO 用户名;"
```

验证结果：

```bash
sudo -u postgres psql -c "\du"     # 查看所有用户
sudo -u postgres psql -c "\l"     # 查看所有数据库
```

### 阶段 5：重启服务

```bash
sudo systemctl restart postgresql
```

确认端口监听：

```bash
sudo ss -tlnp | grep 5432
# 应显示: LISTEN ... 0.0.0.0:5432
```

### 阶段 6：防火墙处理

#### 检查系统防火墙

```bash
# ufw
sudo ufw status
# 如果 inactive —— 无需处理；如果 active —— 执行:
sudo ufw allow 5432/tcp

# iptables（通常默认 ACCEPT 无需处理，但检查一下）
sudo iptables -L INPUT -n | grep 5432

# firewalld（CentOS/RHEL）
sudo firewall-cmd --add-port=5432/tcp --permanent 2>/dev/null
sudo firewall-cmd --reload 2>/dev/null
```

#### ⚠️ 云平台安全组

如果服务器运行在云平台（AWS、阿里云、腾讯云、Azure、GCP 等），系统防火墙放行还不够，必须在云控制台的**安全组/防火墙规则**中添加入站规则：

| 类型 | 协议 | 端口 | 来源 |
|------|------|------|------|
| PostgreSQL（或自定义 TCP） | TCP | 5432 | 本地公网 IP/32（推荐，不用 0.0.0.0/0） |

检测云平台：

```bash
# AWS
curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/instance-id && echo " => AWS"
# 阿里云
curl -s --connect-timeout 2 http://100.100.100.200/latest/meta-data/instance-id && echo " => 阿里云"
# 腾讯云
curl -s --connect-timeout 2 http://metadata.tencentyun.com/latest/meta-data/instance-id && echo " => 腾讯云"
```

如果是云服务器且在阶段 6 之后仍然无法从远程连接，**几乎可以确定是云安全组未放行 5432 端口**。

### 阶段 7：验证连接

```bash
# 本地 TCP 连接测试
PGPASSWORD='用户密码' psql -h 127.0.0.1 -U 用户名 -d 数据库名 -c "SELECT current_user, current_database(), version();"

# 获取公网 IP
hostname -I && curl -s ifconfig.me
```

输出示例：

```
 current_user | current_database | version
--------------+------------------+------------------------------------------------
 myuser       | mydb             | PostgreSQL 16.x (Ubuntu ...) ...
```

连接字符串格式（提供给远程用户）：

```
postgresql://用户名:密码@服务器公网IP:5432/数据库名
```

## 快速参考：创建用户的完整命令

```bash
sudo -u postgres psql -c "CREATE USER 用户名 WITH PASSWORD '密码';"
sudo -u postgres psql -c "CREATE DATABASE 数据库名 OWNER 用户名;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE 数据库名 TO 用户名;"
echo "host    数据库名    用户名    0.0.0.0/0    scram-sha-256" | sudo tee -a $(dirname $(sudo find /etc/postgresql -name pg_hba.conf | head -1))/pg_hba.conf
sudo systemctl reload postgresql
```

## 权限矩阵

| 角色 | 用途 | 远程连接 | 建议 |
|------|------|----------|------|
| `postgres` | 超管 | ❌ 禁止远程，仅限本地 `sudo -u postgres psql` | 设置密码后用 `peer` 认证即可 |
| 专用用户 | 应用/开发 | ✅ 密码认证 + `pg_hba.conf` IP 白名单 | 每个数据库分配不同用户 |
| 只读用户 | 数据分析 | ✅ 密码认证 + 只 `SELECT` 权限 | 切勿给 `CREATEDB` 或 `SUPERUSER` |

## 安全摘要

- **`postgres` 超管不用于远程** —— 永远不要为 `postgres` 在 `pg_hba.conf` 中添加远程规则
- **最小权限原则** —— 专用用户只拥有其工作所需的数据库权限
- **IP 白名单** —— `pg_hba.conf` 中限制来源 IP 而不是用 `0.0.0.0/0`
- **使用 `scram-sha-256`** —— PostgreSQL 10+ 默认更安全的密码哈希
- **强密码** —— 生产环境密码长度 ≥ 16 位并包含多种字符类型

## 故障排查速查表

| 症状 | 可能原因 | 检查命令 |
|------|----------|----------|
| `psql: could not connect to server` | PostgreSQL 未运行 | `sudo systemctl status postgresql` |
| `connection refused` | 未监听外部地址 | `sudo ss -tlnp \| grep 5432`（应显示 `0.0.0.0`） |
| `no pg_hba.conf entry` | 缺少远程认证规则 | `sudo grep -n "^host"`
| `password authentication failed` | 密码错误或哈希不匹配 | `ALTER USER 用户名 WITH PASSWORD '新密码';` |
| `timeout`（云环境） | 安全组未放行 5432 | 去云控制台检查安全组入站规则 |
| 安装后通过 TCP 连接失败 | 默认只允许本地 `peer` 认证 | 修改 `pg_hba.conf` 添加 `host ... scram-sha-256` |

## 配套脚本

- `scripts/install_postgresql.sh` —— 一键安装 PostgreSQL（Ubuntu/Debian）
- `scripts/create_pg_user.sh` —— 创建用户和数据库并添加远程规则
