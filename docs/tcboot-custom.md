# XG-040G-MD tcboot（Web U-Boot）定制固件

分支：`tcboot-custom`。源码：`xiangtailiang/openwrt` main（内核 6.18），机型 `nokia_xg-040g-md-tcboot`，
产物 `openwrt-airoha-an7581-nokia_xg-040g-md-tcboot-squashfs-factory.bin`（在 Web U-Boot 恢复页面刷入）。

## 相对上游的改动

| 项目 | 内容 | 位置 |
|---|---|---|
| 默认地址 | LAN `192.168.8.1` | `diy-tcboot.sh` 改 `config_generate` + `99-xg040-defaults` |
| 主机名 | `XG-040G-MD` | 同上 |
| 语言 / 主题 | 简体中文 / Bootstrap（去掉 Argon） | `99-xg040-defaults`、`diy-tcboot.sh` 第 6 步 |
| turboacc | 流量分载 + 全锥形 NAT + BBR（`--no-sfe`，不打 SFE 内核补丁） | `diy-tcboot.sh` 第 7 步 |
| 定时重启 | `luci-app-autoreboot`（ImmortalWrt 简单版，JS） | `custom/package/luci-app-autoreboot` |
| USB 存储 | NTFS(ntfs3) / exFAT / FAT / ext4 / HFS+ / Btrfs，插上自动挂载到 `/mnt/` | `.config` + `99-xg040-defaults` |
| USB 无线 | RTL8822BU、RTL8821CU（rtw88）、MT7612U（mt76x2u）、AIC8800D80（移植） | `.config`、`custom/package/aic8800` |
| AIC8800 模式切换 | 网卡先以“驱动光盘”出现（a69c:5721），自动弹出切成网卡 | `custom/usbmode/a69c-5721` |
| USB 有线 | RTL8156B 2.5G（r8152） | `.config` |
| 默认网口 | 网口4（千兆）= WAN；网口1（2.5G）、2、3 = LAN | `diy-tcboot.sh` 第 2 步改 `02_network` |
| 网口设置工具 | LuCI「网络 → 网口设置」：横排网口图标（显示连接/速率），每个口下拉选 LAN/WAN；命令行 `portconfig` | `custom/package/luci-app-portconfig` |
| LED | WAN 绿灯 = WAN 口连接/收发（netdev）；WAN-online 绿灯 = WAN 已上线；红灯 = WAN 掉线；可在「系统 → LED 配置」修改，另加 activity/oneshot/pattern/transient 触发器 | `diy-tcboot.sh` 第 2b 步、`custom/files/etc/hotplug.d/iface/90-xg040-wanled` |
| 去掉的 | HomeProxy、PassWall、Argon 主题（不跑上游 `update-packages.sh`） | `build-tcboot-local.sh` |

## 网口对应

| 面板 | 设备名 | 说明 |
|---|---|---|
| 网口1 | `lan1` | 2.5G（EN8811H，独立 GDM，自带 MAC） |
| 网口2 | `lan2` | 千兆（交换机口） |
| 网口3 | `lan3` | 千兆（交换机口） |
| 网口4 | `lan4` | 千兆（交换机口），默认 WAN |

交换机口没有自己的 MAC，`portconfig` 会给 WAN 口固定为 “基础 MAC（U-Boot env 的 ethaddr）+2”，
避免每次开机 WAN MAC 变化。多个口设为 WAN 时自动桥接成 `br-wan`；至少保留一个 LAN 口。

命令行：

```sh
portconfig show          # 查看
portconfig wan lan4      # 网口4 做 WAN（默认）
portconfig wan lan1      # 改用 2.5G 口做 WAN
```

## VM 本地编译

```sh
cd ~/work-xg040/OpenWrt-for-XG-040G-MD
bash scripts/build-tcboot-local.sh prepare   # 重置源码、feeds、第三方包、定制改动、defconfig
bash scripts/build-tcboot-local.sh build     # 下载 + 编译
```

源码固定在 `OPENWRT_REF`（见脚本），要跟进上游时改这个值。
