#!/bin/bash

# 显示欢迎信息
clear
echo "=============================================="
echo "   安全代理服务一键部署脚本（修复版）"
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

# 生成随机UUID
UUID=$(cat /proc/sys/kernel/random/uuid)

# 提示用户输入域名
read -p "请输入您的域名: " DOMAIN

# 停止所有可能占用443端口的服务
echo "停止可能占用443端口的服务..."
docker-compose down 2>/dev/null
systemctl stop nginx 2>/dev/null
systemctl stop apache2 2>/dev/null

# 检查端口是否被占用
if netstat -tuln | grep -q ':443 '; then
  echo "警告: 443端口已被占用，尝试关闭占用此端口的进程..."
  lsof -i :443 | awk 'NR>1 {print $2}' | xargs -r kill -9
  sleep 2
fi

# 安装acme.sh并强制使用Let's Encrypt
echo "安装证书管理工具..."
if [ ! -f "/root/.acme.sh/acme.sh" ]; then
  curl https://get.acme.sh | sh
fi

# 设置默认CA为Let's Encrypt
echo "设置Let's Encrypt为默认证书颁发机构..."
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# 清除可能的旧证书
rm -rf ~/.acme.sh/$DOMAIN
rm -f ./certs/fullchain.pem ./certs/privkey.pem

# 申请证书
echo "正在申请SSL证书，请确保域名 $DOMAIN 已正确解析到此服务器IP..."
~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone -k ec-256 --force

# 检查证书是否申请成功
if [ ! -f ~/.acme.sh/${DOMAIN}_ecc/fullchain.cer ]; then
  echo "证书申请失败，尝试使用HTTP方式验证..."
  ~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --force
fi

# 再次检查证书
if [ ! -f ~/.acme.sh/${DOMAIN}_ecc/fullchain.cer ] && [ ! -f ~/.acme.sh/${DOMAIN}/fullchain.cer ]; then
  echo "证书申请失败。正在尝试使用临时解决方案，不使用TLS加密..."
  
  # 创建无TLS配置的Xray配置
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
            "flow": "",
            "level": 0,
            "email": "user@example.com"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

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

  # 启动服务
  echo "正在启动无TLS代理服务..."
  docker-compose up -d

  # 提示用户
  echo "=============================================="
  echo "注意: 无法申请SSL证书，已使用无TLS加密的备用方案"
  echo "请保存以下信息用于客户端配置："
  echo "=============================================="
  echo "UUID: $UUID"
  echo "服务器地址: $(curl -s icanhazip.com || echo "8.216.124.230")"
  echo "端口: 443"
  echo "加密方式: none"
  echo "传输协议: tcp"
  echo "安全类型: none (没有使用TLS)"
  echo "=============================================="
  echo "建议截图保存以上信息"
  echo "安全提示: 此配置无TLS加密，安全性较低"
  exit 0
else
  # 安装证书到指定目录
  if [ -f ~/.acme.sh/${DOMAIN}_ecc/fullchain.cer ]; then
    # ECC证书
    ~/.acme.sh/acme.sh --installcert -d "$DOMAIN" --fullchainpath ./certs/fullchain.pem --keypath ./certs/privkey.pem --ecc --force
  else
    # RSA证书
    ~/.acme.sh/acme.sh --installcert -d "$DOMAIN" --fullchainpath ./certs/fullchain.pem --keypath ./certs/privkey.pem --force
  fi
fi

# 设置证书权限
chmod 644 ./certs/fullchain.pem
chmod 644 ./certs/privkey.pem

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
  echo "服务启动失败，正在检查日志..."
  docker logs xray
  echo "=============================================="
  echo "可能原因:"
  echo "1. 证书文件权限不正确"
  echo "2. 域名解析错误"
  echo "3. 防火墙限制"
  echo "请尝试运行修复命令: chmod 644 ./certs/*.pem && docker-compose restart"
  echo "=============================================="
fi 