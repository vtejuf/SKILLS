#!/bin/bash
#
# 安装 Node.js（snap）+ codewhale
#
# 使用方法：
#   chmod +x setup_node.sh
#   sudo ./setup_node.sh
#

set -e

echo "=========================================="
echo "  Node.js 环境初始化"
echo "=========================================="

# ---------- 1. apt update ----------
echo ""
echo "第一步：更新包列表..."
echo "----------------------------------------"
sudo apt update

# ---------- 2. 安装 Node.js（snap）----------
echo ""
echo "第二步：安装最新版 Node.js..."
echo "----------------------------------------"

if command -v node &> /dev/null; then
    echo "Node.js 已安装: $(node -v)，跳过"
else
    if ! command -v snap &> /dev/null; then
        echo "未检测到 snap，先安装 snapd..."
        sudo apt install -y snapd
    fi

    echo "使用 snap 安装 Node.js..."
    sudo snap install node --classic #--channel=latest/edge
fi

echo ""
echo "Node.js 版本: $(node -v)"
echo "npm 版本:     $(npm -v)"

# ---------- 3. 安装 codewhale ----------
echo ""
echo "第三步：安装 codewhale..."
echo "----------------------------------------"
sudo npm config set registry https://registry.npmmirror.com
sudo npm config set ignore-scripts false
sudo npm install -g codewhale

echo ""
echo "=========================================="
echo "  安装完成"
echo "=========================================="
echo ""
echo "已安装组件："
echo "  Node.js:    $(node -v)"
echo "  npm:        $(npm -v)"
echo "  npm 源:     $(npm config get registry)"
echo "  codewhale:  已安装"
echo ""
