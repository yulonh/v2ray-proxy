#!/bin/bash

# 显示欢迎信息
clear
echo "=============================================="
echo "   安全代理服务一键部署脚本"
echo "=============================================="
echo ""

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
  echo "错误: 必须使用root权限运行此脚本"
  exit 1
fi

# 安装必要的软件包
echo "正在安装必要的软件包..."
apt update
apt install -y curl wget unzip socat

# 安装Docker和Docker Compose
if ! command -v docker &> /dev/null; then
  echo "正在安装Docker..."
  curl -fsSL https://get.docker.com | bash
fi

if ! command -v docker-compose &> /dev/null; then
  echo "正在安装Docker Compose..."
  curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

# 创建目录并运行服务
echo "正在准备启动代理服务..."

# 询问是否配置防火墙
read -p "是否配置防火墙? (y/n): " configure_firewall
if [ "$configure_firewall" = "y" ] || [ "$configure_firewall" = "Y" ]; then
  echo "正在配置防火墙..."
  chmod +x firewall.sh
  ./firewall.sh
fi

# 运行安装脚本
echo "请按照以下提示配置代理服务..."
chmod +x setup.sh
./setup.sh

# 启动服务
echo "正在启动代理服务..."
docker-compose up -d

# 检查服务状态
if docker ps | grep -q "xray"; then
  echo "=============================================="
  echo "代理服务部署成功!"
  echo "请使用上述配置信息在客户端进行设置"
  echo "=============================================="
else
  echo "=============================================="
  echo "服务启动失败，请查看日志排查问题"
  echo "可以运行: docker-compose logs v2ray"
  echo "=============================================="
fi 