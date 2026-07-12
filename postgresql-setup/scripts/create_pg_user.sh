#!/usr/bin/env bash
# PostgreSQL 用户创建脚本
# 用法: sudo bash create_pg_user.sh <用户名> <密码> <数据库名> [来源IP]
#       来源IP 是可选的，默认为 0.0.0.0/0（所有 IP），仅用于测试
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "用法: sudo bash create_pg_user.sh <用户名> <密码> <数据库名> [来源IP]"
  echo "示例: sudo bash create_pg_user.sh myapp 'MyStr0ng!Pass' myapp_db 192.168.1.0/24"
  echo "示例: sudo bash create_pg_user.sh test 'test123' test_db"
  exit 1
fi

USERNAME="$1"
PASSWORD="$2"
DBNAME="$3"
SOURCE_IP="${4:-0.0.0.0/0}"

echo "=== [1/5] 创建用户: $USERNAME ==="
sudo -u postgres psql -c "CREATE USER \"$USERNAME\" WITH PASSWORD '$PASSWORD';"

echo "=== [2/5] 创建数据库: $DBNAME (owner: $USERNAME) ==="
sudo -u postgres psql -c "CREATE DATABASE \"$DBNAME\" OWNER \"$USERNAME\";"

echo "=== [3/5] 授予权限 ==="
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"$DBNAME\" TO \"$USERNAME\";"

echo "=== [4/5] 添加远程访问规则 ==="
PG_HBA=$(sudo find /etc/postgresql -name pg_hba.conf | head -1)
if [ -z "$PG_HBA" ]; then
  echo "警告: 找不到 pg_hba.conf，跳过远程规则添加"
else
  RULE="host    $DBNAME    $USERNAME    $SOURCE_IP    scram-sha-256"
  echo "$RULE" | sudo tee -a "$PG_HBA"
  echo "已添加规则: $RULE"
fi

echo "=== [5/5] 重载 PostgreSQL ==="
sudo systemctl reload postgresql

echo ""
echo "=== 用户创建完成 ==="
echo "用户:     $USERNAME"
echo "数据库:   $DBNAME"
echo "来源 IP:  $SOURCE_IP"
echo ""
echo "验证连接: PGPASSWORD='$PASSWORD' psql -h 127.0.0.1 -U $USERNAME -d $DBNAME -c 'SELECT 1;'"
echo "连接串:   postgresql://$USERNAME:$PASSWORD@<服务器IP>:5432/$DBNAME"
echo ""
echo "现有用户列表:"
sudo -u postgres psql -c "\du"
