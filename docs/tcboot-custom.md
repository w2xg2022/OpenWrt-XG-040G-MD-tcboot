# XG-040G-MD 定制固件（bell 机型，Web U-Boot 刷入）

分支：`tcboot-custom`。源码：`xiangtailiang/openwrt` `openwrt-25.12`（内核 6.12，固定版本），机型 `bell_xg-040g-md`（与上游能用的固件一致），
产物 `openwrt-airoha-an7581-bell_xg-040g-md-squashfs-factory.bin`（在 Web U-Boot 恢复页面刷入）。

> 一开始曾误用主线的 `nokia_xg-040g-md-tcboot` 机型（内核 6.18），在实机上网口不通，已改回上游实测可用的 bell 机型。

## 相对上游的改动

| 项目 | 内容 | 位置 |
|---|---|---|
| 默认地址 | LAN `192.168.1.1` | `diy-tcboot.sh` 改 `config_generate` + `99-xg040-defaults` |
| 主机名 | `XG-040G-MD` | 同上 |
| 语言 / 主题 | 简体中文 / Bootstrap（去掉 Argon） | `99-xg040-defaults`、`diy-tcboot.sh` 第 6 步 |
| turboacc | 流量分载 + 全锥形 NAT + BBR（`--no-sfe`，不打 SFE 内核补丁） | `diy-tcboot.sh` 第 7 步 |
| 定时重启 | `luci-app-autoreboot`（ImmortalWrt 简单版，JS） | `custom/package/luci-app-autoreboot` |
| USB 存储 | NTFS(ntfs3) / exFAT / FAT / ext4 / HFS+ / Btrfs，插上自动挂载到 `/mnt/` | `.config` + `99-xg040-defaults` |
| USB 无线 | RTL8822BU、RTL8821CU（rtw88）、MT7612U（mt76x2u）、AIC8800D80（移植） | `.config`、`custom/package/aic8800` |
| AIC8800 模式切换 | 网卡先以“驱动光盘”出现（a69c:5721），自动弹出切成网卡 | `custom/usbmode/a69c-5721` |
| USB 有线 | RTL8156B 2.5G（r8152） | `.config` |
| 默认网口 | 网口4（千兆）= WAN；网口1（2.5G）、2、3 = LAN | `diy-tcboot.sh` 第 2 步改 `02_network`（`eth1 lan2 lan3` / `lan4`） |
| 网口设置工具（暂停，未编进固件） | LuCI「网络 → 网口设置」：横排网口图标（显示连接/速率），每个口下拉选 LAN/WAN；命令行 `portconfig` | `custom/package/luci-app-portconfig` |
| LED | `green:pon` = WAN 口连接/收发（netdev）；`green:internet` = WAN 已上线；`red:los` = WAN 掉线；网口灯由硬件控制；可在「系统 → LED 配置」修改，另加 activity/oneshot/pattern/transient 触发器 | `diy-tcboot.sh` 第 2b 步、`custom/files/etc/hotplug.d/iface/90-xg040-wanled` |
| 去掉的 | HomeProxy、PassWall、Argon 主题（不跑上游 `update-packages.sh`） | `build-tcboot-local.sh` |

## 网口对应

| 面板 | 设备名 | 说明 |
|---|---|---|
| 网口1 | `eth1` | 2.5G（EN8811H，独立 GDM；上游原本当 WAN） |
| 网口2 | `lan2` | 千兆（交换机口） |
| 网口3 | `lan3` | 千兆（交换机口） |
| 网口4 | `lan4` | 千兆（交换机口），默认 WAN |

WAN 的 MAC 设在 `wan` 接口上（上游 `02_network` 从 U-Boot env 读 ethaddr），换哪个口当 WAN 都沿用。多个口设为 WAN 时自动桥接成 `br-wan`；至少保留一个 LAN 口。

命令行：

```sh
portconfig show          # 查看
portconfig wan lan4      # 网口4 做 WAN（默认）
portconfig wan eth1      # 改用 2.5G 口做 WAN（上游原本的做法）
```

## VM 本地编译

```sh
cd ~/work-xg040/OpenWrt-for-XG-040G-MD
bash scripts/build-tcboot-local.sh prepare   # 重置源码、feeds、第三方包、定制改动、defconfig
bash scripts/build-tcboot-local.sh build     # 下载 + 编译
```

源码固定在 `OPENWRT_REF`（见脚本），要跟进上游时改这个值。

## 网口分配（当前）

暂时保持上游分配：网口2~4（lan2~lan4）= LAN，2.5G 口（eth1）= WAN。网口工具 `luci-app-portconfig` 源码保留，暂不编进固件。

## ImageBuilder 快速出包

- 完整编译（`Build_XG_040G_MD_tcboot`）只手动触发，跑完会把 ImageBuilder 更新到 `imagebuilder` Release。
- 日常推送改动以下文件时，`Build_XG_040G_MD_ImageBuilder` 自动用 ImageBuilder 几分钟出固件（Release tag 前缀 `ib-`）：
  - `config/ib-packages.txt`：软件包清单（`-包名` 表示不装）
  - `custom/files/`：首次开机默认设置
  - `custom/ib-overlay/`：board.d 网口/LED 分配
- 本地：`bash scripts/build-ib.sh <ImageBuilder 解压目录> [输出目录]`
- 改驱动、内核、feeds，或新增 ImageBuilder 里没有的包，要先跑一次完整编译。
