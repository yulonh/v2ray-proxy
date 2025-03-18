#!/bin/bash

# 确保目录存在
mkdir -p config logs certs

# 生成随机UUID并更新配置文件
UUID=$(cat /proc/sys/kernel/random/uuid)
sed -i "s/00000000-0000-0000-0000-000000000000/$UUID/g" config/config.json

# 生成密码用于客户端配置
PASSWORD=$(openssl rand -base64 16)
echo "=============================================="
echo "UUID: $UUID"
echo "服务器地址: 请输入您的域名"
echo "端口: 443"
echo "加密方式: none"
echo "传输协议: tcp"
echo "安全类型: tls"
echo "流控: xtls-rprx-vision"
echo "=============================================="
echo "请将以上信息保存，用于客户端配置"

# 询问用户输入域名
read -p "请输入您的域名: " DOMAIN

# 安装acme.sh
if [ ! -f "/root/.acme.sh/acme.sh" ]; then
  curl https://get.acme.sh | sh
fi

# 申请SSL证书
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d $DOMAIN --fullchainpath ./certs/fullchain.pem --keypath ./certs/privkey.pem --ecc

# 设置权限
chmod +r ./certs/fullchain.pem
chmod +r ./certs/privkey.pem

echo "证书已生成，现在可以运行 docker-compose up -d 启动服务" 