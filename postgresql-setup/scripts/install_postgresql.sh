#!/usr/bin/env bash
# PostgreSQL 一键安装脚本 (Ubuntu/Debian)
# 用法: sudo bash install_postgresql.sh [postgres密码]
#       默认 postgres 密码为 "postgres"，可通过参数覆盖
set -euo pipefail

POSTGRES_PW="${1:-postgres}"

# 检查是否为 Ubuntu/Debian
if ! grep -qiE 'ubuntu|debian' /etc/os-release 2>/dev/null; then
  echo "此脚本仅适用于 Ubuntu/Debian 系统。其他系统请手动安装。"
  exit 1
fi

echo "=== [1/6] 更新包列表 ==="
sudo apt update -qq

echo "=== [2/6] 安装 PostgreSQL ==="
sudo apt install -y postgresql postgresql-contrib

echo "=== [3/6] 设置 postgres 超管密码 ==="
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$POSTGRES_PW';"

echo "=== [4/6] 修改监听地址 ==="
PG_CONF=$(sudo find /etc/postgresql -name postgresql.conf | head -1)
if [ -z "$PG_CONF" ]; then
  echo "错误: 找不到 postgresql.conf"
  exit 1
fi
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"

echo "=== [5/6] 重启 PostgreSQL ==="
sudo systemctl restart postgresql

echo "=== [6/6] 验证安装 ==="
echo "版本: $(psql --version 2>/dev/null || echo 'psql 未安装')"
echo "监听状态:"
sudo ss -tlnp | grep 5432 || echo "  注意: 端口 5432 未监听，请检查 postgresql.conf"

echo ""
echo "=== 安装完成 ==="
echo "超管用户: postgres (仅限本地 sudo -u postgres psql)"
echo "配置文件: $PG_CONF"
echo "pg_hba.conf: $(dirname "$PG_CONF")/pg_hba.conf"
echo ""
echo "下一步: 使用 create_pg_user.sh 创建专用用户"
echo "或手动: sudo -u postgres psql -c \"CREATE USER 用户名 WITH PASSWORD '密码';\""
