# 安全代理服务一键部署

这是一个基于Xray的安全代理服务，使用Docker Compose进行一键部署。

## 特点

- 使用VLESS+XTLS+Vision协议，提供高速稳定的连接
- TLS加密保证数据传输安全
- 自动申请和续签SSL证书
- 使用Watchtower自动更新容器镜像
- 配置简单，一键部署

## 一键安装

在服务器上运行以下命令进行一键安装：

```bash
wget -N --no-check-certificate https://raw.githubusercontent.com/YOUR_USERNAME/v2ray-proxy/main/install.sh && chmod +x install.sh && bash install.sh
```

> 注意：请将上述链接中的YOUR_USERNAME替换为您的GitHub用户名，如果您已经将此项目上传到GitHub仓库。

## 手动部署步骤

如果您不想使用一键安装脚本，可以按照以下步骤手动部署：

1. 确保服务器已安装Docker和Docker Compose:

```bash
# 安装Docker
curl -fsSL https://get.docker.com | bash

# 安装Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

2. 克隆或下载此仓库到服务器

3. 配置防火墙 (可选但推荐):

```bash
chmod +x firewall.sh
./firewall.sh
```

4. 运行安装脚本:

```bash
cd v2ray-proxy
chmod +x setup.sh
./setup.sh
```

5. 按照提示输入您的域名并等待证书生成

6. 启动服务:

```bash
docker-compose up -d
```

## 客户端配置

安装脚本会生成必要的配置信息，包括：

- UUID
- 服务器地址（您的域名）
- 端口（443）
- 加密方式（none）
- 传输协议（tcp）
- 安全类型（tls）
- 流控（xtls-rprx-vision）

您可以使用这些信息在以下客户端配置您的代理：
- v2rayN (Windows)
- V2rayU (Mac)
- v2rayNG (Android)
- Shadowrocket (iOS)

## 安全建议

- 请确保服务器的443端口已开放
- 配置客户端时，服务器地址必须与申请证书时使用的域名一致
- 定期备份config.json文件以防配置丢失
- 使用防火墙限制对服务器的访问
- 定期更新服务器系统和软件
- 考虑使用CDN服务(如Cloudflare)来隐藏真实IP

## 故障排除

如果连接不上服务，请检查：

1. 服务器防火墙是否开放443端口
2. 证书是否正确生成
3. 客户端配置是否与服务器一致
4. 查看日志: `docker-compose logs v2ray` 