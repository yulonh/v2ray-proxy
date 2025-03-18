#!/bin/bash

# 显示欢迎信息
clear
echo "=============================================="
echo "   安全代理服务一键部署脚本"
echo "   作者: yulonh"
echo "   项目: https://github.com/yulonh/v2ray-proxy"
echo "=============================================="
echo ""

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
  echo "错误: 必须使用root权限运行此脚本"
  exit 1
fi

# 创建工作目录
WORK_DIR="/opt/v2ray-proxy"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# 创建必要的子目录
mkdir -p config logs certs

# 安装必要的软件包
echo "正在安装必要的软件包..."
apt update
apt install -y curl wget unzip socat ufw

# 配置防火墙
echo "正在配置防火墙..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 443/tcp
ufw allow 443/udp
echo "y" | ufw enable

# 安装Docker
if ! command -v docker &> /dev/null; then
  echo "正在安装Docker..."
  curl -fsSL https://get.docker.com | bash
fi

# 安装Docker Compose
if ! command -v docker-compose &> /dev/null; then
  echo "正在安装Docker Compose..."
  curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

# 创建Docker Compose配置文件
cat > docker-compose.yml << EOF
version: '3'

services:
  v2ray:
    image: teddysun/xray:latest
    container_name: xray
    restart: always
    ports:
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./config:/etc/xray
      - ./logs:/var/log/xray
      - ./certs:/etc/ssl/xray
    environment:
      - TZ=Asia/Shanghai
    networks:
      - proxy-network

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 86400 --cleanup
    networks:
      - proxy-network

networks:
  proxy-network:
    driver: bridge
EOF

# 生成随机UUID
UUID=$(cat /proc/sys/kernel/random/uuid)

# 创建Xray配置文件
cat > config/config.json << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID", 
            "flow": "xtls-rprx-vision",
            "level": 0,
            "email": "user@example.com"
          }
        ],
        "decryption": "none",
        "fallbacks": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["http/1.1", "h2"],
          "certificates": [
            {
              "certificateFile": "/etc/ssl/xray/fullchain.pem",
              "keyFile": "/etc/ssl/xray/privkey.pem"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "tag": "blocked",
      "settings": {}
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF

# 提示用户输入域名
read -p "请输入您的域名: " DOMAIN

# 安装acme.sh
if [ ! -f "/root/.acme.sh/acme.sh" ]; then
  curl https://get.acme.sh | sh
fi

# 安装证书
echo "正在安装SSL证书，请确保您的域名已正确解析到此服务器..."
~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d "$DOMAIN" --fullchainpath ./certs/fullchain.pem --keypath ./certs/privkey.pem --ecc

# 设置证书权限
chmod +r ./certs/fullchain.pem
chmod +r ./certs/privkey.pem

# 启动服务
echo "正在启动代理服务..."
docker-compose up -d

# 检查服务状态
if docker ps | grep -q "xray"; then
  echo "=============================================="
  echo "代理服务部署成功!"
  echo "请保存以下信息用于客户端配置："
  echo "=============================================="
  echo "UUID: $UUID"
  echo "服务器地址: $DOMAIN"
  echo "端口: 443"
  echo "加密方式: none"
  echo "传输协议: tcp"
  echo "安全类型: tls"
  echo "流控: xtls-rprx-vision"
  echo "=============================================="
  echo "建议截图保存以上信息"
  echo "遇到问题请访问: https://github.com/yulonh/v2ray-proxy/issues"
else
  echo "=============================================="
  echo "服务启动失败，请运行以下命令查看日志："
  echo "cd $WORK_DIR && docker-compose logs v2ray"
  echo "=============================================="
fi 