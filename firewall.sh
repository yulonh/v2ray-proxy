#!/bin/bash

# 安装防火墙
apt update
apt install -y ufw

# 设置默认策略
ufw default deny incoming
ufw default allow outgoing

# 开放SSH和HTTPS端口
ufw allow ssh
ufw allow 443/tcp
ufw allow 443/udp

# 启用防火墙
echo "y" | ufw enable

# 显示防火墙状态
ufw status

echo "防火墙配置完成，已开放SSH和443端口" 