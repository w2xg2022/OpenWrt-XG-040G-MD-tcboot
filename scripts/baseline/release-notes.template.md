## OpenWrt {{OPENWRT_BRANCH_VER}} · XG-040G-MD 固件

| 项目 | 内容 |
|---|---|
| 设备型号 | XG-040G-MD（Nokia Bell / Airoha AN7581） |
| 构建时间 | {{BUILD_TIME}} |
| 内核版本 | {{KERNEL_VERSION}} |
| 源码仓库 | {{SOURCE_REPO}} |
| 分支 | {{SOURCE_BRANCH}} |
| 源码 commit | `{{SOURCE_COMMIT}}` |
| 构建脚本仓库 | {{REPO_URL}}（commit `{{REPO_COMMIT}}`） |
| 默认 IP | `192.168.1.1`（子网掩码 255.255.255.0） |
| 默认账号 / 密码 | `root` / `anytoolab.com` |
| 默认主机名 | `XG-040G-MD` |
| 默认时区 | Asia/Shanghai（CST-8） |

> 首次登录后请尽快修改默认密码。

### 网口

| 面板 | 系统名称 | 用途 |
|---|---|---|
| 2.5G 口 | `eth1` | LAN |
| 千兆 2 / 3 | `lan2` / `lan3` | LAN |
| 千兆 4 | `lan4` | **WAN**（DHCP 客户端） |
| USB 2.5G 网卡 | `eth2` | 插上后自动加入 LAN，首页「端口状态」最右边显示 |

### 固件文件

| 文件 | 用途 |
|---|---|
| `*-squashfs-factory.bin` | 从原厂固件 / U-Boot 首次刷入 |
| `*-squashfs-sysupgrade.bin` | 已在运行 OpenWrt 时升级（建议不保留配置） |

MD5：

```
{{MD5_LIST}}
```

### 主要特性

- **界面**：LuCI Bootstrap 主题，简体中文
- **加速**：Turbo ACC（Flow Offloading / FullCone NAT / BBR），SQM 队列管理
- **存储**：自动挂载（block-mount）、NTFS、磁盘管理（diskman）
- **工具**：网页终端（ttyd）、定时重启、curl（含 https 根证书）
- **首页**：端口状态显示 USB 网卡；DHCP 租约显示设备在线 / 离线
- **LED**：命令行一键关闭 / 恢复所有灯（含网口灯），重启后保持

### USB 无线网卡

内置驱动：RTL8821CU、RTL8822BU（rtw88）、MT7612U（mt76）、**AIC8800D80**。
USB 2.5G 有线网卡：RTL8156B（r8152）。

- **AIC8800D80（1111:1111 / 88M80）**：出厂是假光盘，插上后**自动切换**成无线模式，无需手动操作。
- **换卡自动整理**：拔掉网卡后自动清除旧的无线配置，插上新卡后自动载入，「网络 → 无线」菜单随之出现。
- 没有插无线网卡时，「网络 → 无线」菜单不显示（LuCI 原生行为）。

### LED 一键开关

```sh
ledctl off       # 关闭所有灯，重启后仍保持关闭
ledctl on        # 恢复正常灯号
ledctl status    # 查看当前状态
```

### 已知限制

- USB3 口（如 U 盘 / 硬盘）与 USB2 口同时接设备时，可能因供电不足导致设备无法驱动或不稳定；建议大功耗设备使用带外接电源的 USB Hub。
- {{KNOWN_ISSUES}}

### 刷机提醒

- 刷机时**不要保留旧配置**，否则会沿用旧的 LAN 地址与无线设置。
- 默认 LAN 为 `192.168.1.1`，若上游路由也是 `192.168.1.x`，请先把电脑直接接到 LAN 口再登录，或之后修改 LAN 地址避免冲突。
