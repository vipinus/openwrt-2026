# OpenWrt-2026 项目文档

## 概述

自定义 OpenWrt 路由器固件，集成 VPN 客户端、智能分流、LuCI 管理界面。支持 776 路由器型号 (OpenWrt 25.12.2 同步, ≥16M flash)，通过 GitHub Actions 自动构建。

## 项目结构

```
openwrt-2026/
├── files/                          # 嵌入固件的自定义文件
│   ├── etc/
│   │   ├── config/vipin            # UCI 默认配置
│   │   ├── init.d/
│   │   │   ├── vipin-vpn           # VPN 启动脚本 (START=90)
│   │   │   └── vipin-auth          # 认证守护进程 (START=95)
│   │   └── uci-defaults/zzz-defaults  # 首次启动配置
│   └── usr/
│       ├── sbin/                   # 核心脚本
│       │   ├── vipin-auth          # 用户认证
│       │   ├── vipin-auth-check    # 后台监控守护进程
│       │   ├── vipin-detect        # IP/国家检测
│       │   ├── vipin-country-ips   # IP 段管理 (分流用)
│       │   ├── vipin-vpn-routing   # nftables 防火墙规则
│       │   └── vipin-vpnc-script   # OpenConnect 接口配置
│       └── lib/lua/luci/
│           ├── controller/vpn.lua  # LuCI 控制器
│           └── view/vpn/settings.htm # LuCI 界面 (17 种语言)
├── configs/                        # 776 路由器型号配置 (OpenWrt 25.12.2)
│   ├── ASUS-RT-AC68U.config
│   ├── GLINET-GL-MT300N-V2.config
│   └── ...
└── .github/workflows/build.yml    # GitHub Actions 构建
```

## 核心脚本

### vipin-auth — 用户认证

```bash
vipin-auth login <用户名> <密码>     # 登录
vipin-auth logout                    # 登出
vipin-auth status                    # 查看登录状态
vipin-auth check                     # 远程验证账号有效性
vipin-auth mac                       # 获取路由器 MAC
```

**认证流程**:
1. 调用远程 API `POST /api/v1/router-auth` (source=router-plain)
2. 远程失败则 fallback 到本地 MySQL
3. 成功后保存 `/etc/vipin/auth.conf` 和 `/etc/vipin/.vpn_pass`
4. 凭据文件永不自动删除，只有用户手动 logout 才清除

**注意**: 路由器上没有 openssl 和 MySQL，所有功能必须通过远程 API 或本地文件实现。

### vipin-vpn (init.d) — VPN 启动

**连接流程**:
1. `check_auth` — 检查 `vipin-auth status` 返回 `logged_in: true`
2. `fetch_cert_pin` — 获取服务器 TLS 证书指纹
3. 生成随机端口 (50000-59999)
4. 创建 `/tmp/vipin/vpn_start.sh` 启动脚本
5. 通过 procd 启动 openconnect

**OpenConnect 参数**:
- `--protocol=anyconnect`
- `--servercert pin-sha256:...` (不支持 --no-cert-check, v9.12 已移除)
- `--script /usr/sbin/vipin-vpnc-script` (自定义，不用系统默认)
- `--interface vpn_vipin`
- 端口: 随机 50000-59999

### vipin-vpnc-script — VPN 接口配置

替代 OpenWrt 默认的 `/lib/netifd/vpnc-script` (因为 netifd 不兼容)。

连接时:
- `ip link set dev $TUNDEV up`
- `ip addr add $INTERNAL_IP4_ADDRESS/32 dev $TUNDEV`
- 添加 0.0.0.0/1 + 128.0.0.0/1 路由 (覆盖默认路由)
- 配置 DNS

### vipin-auth-check — 后台监控

守护进程，每 30 秒检查一次:
- VPN 进程是否存活，死了就重连
- 每 5 分钟通过远程 API 验证账号有效性
- **不会禁用 VPN 或删除凭据** (只记录日志)

### vipin-detect — 国家检测

```bash
vipin-detect auto    # 自动检测 IP 和国家
vipin-detect info    # 查看检测结果
```

使用 `http://ip-api.com` (注意: 免费版只支持 HTTP) 和 `https://ipinfo.io`。

### vipin-country-ips — IP 段管理

```bash
vipin-country-ips update cn    # 下载中国 IP 段
vipin-country-ips count cn     # 查看 IP 段数量
```

从 ipdeny.com 下载国家 IP 段，用于智能分流。

## UCI 配置

`/etc/config/vipin`:

```
config vpn 'vpn'
    option enabled '0'           # VPN 开关
    option server ''             # 服务器域名 (如 jp.fanq.in)
    option username ''           # 登录用户名
    option split_tunnel '1'      # 智能分流 (默认开启)
    option country 'cn'          # 国内 IP 国家代码
```

## LuCI 界面

### 控制器 (vpn.lua)

语言跟随 LuCI 系统设置 (`uci get luci.main.lang`)，支持 `zh_Hans` → `zh-CN` 映射。

**JSON 解析注意**: `vipin-auth` 输出的 JSON 有空格 (`"key": "value"`)，grep/match 模式必须用 `"key":%s*"value"` 或 `"key": *"value"` 兼容。

### 界面 (settings.htm)

- 包含 `<%+header%>` 和 `<%+footer%>` 以集成 LuCI 导航
- 内联 17 种语言的 i18n 字典
- 服务器列表: 页面加载时用本地硬编码数据，刷新时从 API 获取
- 登录成功自动连接 VPN，无手动连接按钮

## GitHub Actions 构建

### 触发方式

1. `repository_dispatch` — vpn-next 后端通过 API 触发
2. `workflow_dispatch` — 手动触发

### 构建参数

| 参数 | 说明 |
|------|------|
| `target` | 路由器型号 (如 GLINET-GL-MT300N-V2) |
| `version` | 固件版本 (YYYYMMDD) |
| `language` | LuCI 语言 (en, zh_Hans, ja 等) |
| `build_id` | 内部 ID (webhook 回调用) |
| `callback_url` | 构建完成回调 URL |

### 构建流程

1. 克隆 OpenWrt v25.12.2
2. 复制 `files/` 到固件
3. 只保留 en + 用户选择的语言 locale
4. 加载 `configs/{MODEL}.config`
5. `make download && make -j4 world`
6. 上传 artifact，回调 webhook

### 构建限制

- 并行: `-j4` (7GB RAM runner 防 OOM)
- 每用户每 24 小时最多 3 次构建
- 构建时间约 2 小时

## 常见问题

### JSON 空格不匹配

shell 脚本输出 `"key": "value"` (有空格)，但 grep 匹配时可能用 `"key":"value"` (无空格)。始终用 `"key": *"value"` 模式。

### OpenConnect v9.12

- `--no-cert-check` 已被移除，必须用 `--servercert pin-sha256:...`
- 通过故意传错误 pin 获取正确 pin: openconnect 报错会显示实际 pin

### 路由器没有 openssl/MySQL

所有依赖 openssl 或 MySQL 的功能必须通过远程 API 实现:
- 认证: 通过 HTTPS 明文传输 (source=router-plain)
- 账号验证: 通过 /api/v1/router-auth?source=verify
- 密钥: 通过 /api/v1/router/key API 获取

### TUNSETIFF: Resource busy

openconnect 重连前必须先清理旧的 tun 设备:
```bash
killall openconnect 2>/dev/null
ip link delete vpn_vipin 2>/dev/null
```
