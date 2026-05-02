# ViPiN OpenWRT Firmware

基于 OpenWRT v25.12.2 定制的路由器固件，预装 LuCI web 管理界面、OpenConnect VPN 和 DNSCrypt-proxy。

## 支持的路由器

共 **1092** 款路由器，涵盖以下品牌：

- ASUS
- TP-Link
- NETGEAR
- Linksys
- Xiaomi
- GL.iNet
- D-Link
- TP-Link (Archer, Deco, EAP)
- NETGEAR (R-series, Orbi, Nighthawk)
- Linksys (E, EA, MR, MX, WHW series)
- Ubiquiti (UniFi, EdgeRouter, airCube)
- Zyxel
- 小米/红米
- Mercusys
- Cudy
- TOTOLINK
- 以及更多...

完整列表见 [supported_list.txt](supported_list.txt)

## 主要功能

### 预装软件包

- **LuCI** - OpenWRT web 管理界面
- **OpenConnect** - AnyConnect 兼容 VPN 客户端
- **DNSCrypt-proxy** - DNS 加密
- **FireWall** - 防火墙
- **UPnP** - 通用即插即用
- **DDNS** - 动态域名服务
- **ipset** - IP 集合管理
- **nftables** - 防火墙规则

### 默认设置

| 设置项 | 默认值 |
|--------|--------|
| 管理员密码 | www.anyfq.com |
| WiFi SSID | www.anyfq.com |
| WiFi 密码 | www.anyfq.com |
| LAN IP 地址 | 192.168.11.1 |
| 主机名 | 20260406 |
| Web 管理界面 | http://192.168.11.1 |
| WiFi | 默认开启 |

### 语言支持

- 英文 (默认)

## 构建固件

### 方式一：网站在线构建

访问 https://www.anyfq.com/firmware-builder 选择路由器型号，一键构建。

### 方式二：本地构建

#### 前置要求

- Ubuntu 22.04 或更高版本
- 至少 4GB RAM
- 50GB 可用磁盘空间
- 稳定的网络连接

#### 构建步骤

```bash
# 克隆仓库
git clone https://github.com/vipinus/openwrt-2026.git
cd openwrt-2026

# 安装依赖
sudo apt-get update
sudo apt-get install -y build-essential ccache flex bison g++ gcc libc-dev \
    python3 python3-pip python3-setuptools python3-wheel \
    libncurses-dev libssl-dev zlib1g-dev libelf-dev autoconf \
    automake libtool pkg-config unzip rsync wget git curl \
    subversion bc findutils tar bzip2 gzip

# 选择路由器配置
# 配置文件位于 configs/ 目录
ls configs/*.config | head -10

# 复制配置文件
cp configs/GLINET-GL-MT300N-V2.config .config

# 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 生成完整配置
make defconfig

# 下载源码
make download -j$(nproc)

# 构建固件 (约 30-90 分钟)
make -j4 world V=s
```

### 方式三：GitHub Actions

使用 GitHub 仓库的 workflow 自动构建：

1. Fork 本仓库
2. 进入 Actions 页面
3. 选择 "Build OpenWRT Firmware"
4. 输入路由器型号（如 GLINET-GL-MT300N-V2）
5. 点击运行

## 配置文件格式

每个路由器的配置文件仅需 20-21 行：

```bash
CONFIG_TARGET_ramips=y
CONFIG_TARGET_ramips_mt76x8=y
CONFIG_TARGET_ramips_mt76x8_DEVICE_glinet_gl-mt300n-v2=y

CONFIG_LUCI_LANG_en=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_luci-app-firewall=y
CONFIG_PACKAGE_luci-app-opkg=y
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-ddns=y
CONFIG_PACKAGE_dnscrypt-proxy=y
CONFIG_PACKAGE_ipset=y
CONFIG_PACKAGE_nftables=y
CONFIG_PACKAGE_miniupnpd=y
CONFIG_PACKAGE_ddns-scripts=y
CONFIG_PACKAGE_ddns-scripts-services=y
CONFIG_PACKAGE_luci-proto-openconnect=y
CONFIG_PACKAGE_openconnect=y
```

## 目录结构

```
.
├── .github/
│   └── workflows/
│       └── build.yml          # GitHub Actions 构建脚本
├── configs/                    # 路由器配置文件 (1092 个)
│   ├── GLINET-GL-MT300N-V2.config
│   ├── LINKSYS-WRT3200ACM.config
│   └── ...
├── files/                     # 自定义文件 (会复制到固件)
│   └── etc/
│       ├── config/           # UCI 配置文件
│       │   ├── dropbear
│       │   ├── firewall
│       │   ├── network
│       │   ├── system
│       │   └── wireless
│       ├── init.d/           # 启动脚本
│       └── uci-defaults/     # 首次启动配置
│           └── zzz-wireless-default
│       └── lib/
│           └── lua/
│               └── luci/
│                   ├── controller/  # LuCI 控制器
│                   │   ├── vipin.lua
│                   │   └── vpn.lua
│                   └── view/        # LuCI 模板
│                       ├── vipin/
│                       │   └── status.htm
│                       └── vpn/
│                           └── settings.htm
└── supported_list.txt       # 支持的路由器列表
```

## LuCI 界面

### ViPiN 固件管理

- 系统状态
- 版本信息
- 语言切换
- 在线更新

### VPN 设置

- OpenConnect VPN 配置
- 分流隧道
- 服务器节点选择
- 流量统计

## 技术支持

- 网站: https://www.anyfq.com
- GitHub Issues: https://github.com/vipinus/openwrt-2026/issues

## 构建输出

构建完成后，固件文件位于 `bin/targets/` 目录下：

- `*-sysupgrade.bin` - 升级包
- `*-factory.bin` - 工厂固件（全新安装）
- `*-initramfs.bin` - RAM 启动镜像

## 刷入固件

### 通过 LuCI Web 界面

1. 登录 LuCI (http://192.168.11.1)
2. 进入 System → Backup / Flash Firmware
3. 在 "Flash new firmware" 部分选择 .bin 文件
4. 点击 "Flash Image"
5. 等待刷入完成（约 3-5 分钟）

### 通过 SSH/Telnet

```bash
# 上传固件到路由器
scp openwrt-*.bin root@192.168.11.1:/tmp/

# SSH 登录
ssh root@192.168.11.1

# 刷入固件
sysupgrade -v /tmp/openwrt-*.bin
```

## 常见问题

### Q: 构建失败怎么办？

A: 检查错误日志，常见问题包括：
- 磁盘空间不足（需要 50GB+）
- 网络连接不稳定（下载源码超时）
- 内存不足（增加 swap 或减少并行编译数）

### Q: 某个路由器配置缺失？

A: 可以从 OpenWRT 官方获取配置：
```bash
# 使用 OpenWRT Image Builder
git clone --depth 1 --branch v25.12.2 https://github.com/openwrt/openwrt.git
cd openwrt
make menuconfig  # 选择路由器
make defconfig
cat .config | grep CONFIG_TARGET_ | grep =y
```

### Q: 如何添加新的路由器支持？

A:
1. 在 OpenWRT 中找到该路由器的 target/device 配置
2. 创建 `configs/VENDOR-MODEL.config` 文件
3. 添加到 `supported_list.txt`
4. 在 website 的 firmware.ts 中添加路由器信息

## 许可证

本项目基于 OpenWRT 开源许可证。

OpenWRT 相关组件遵循 GPLv2 许可证。
