# OpenWrt for XG-040G-MD（Web U-Boot 刷入，定制版）

NOKIA BELL XG-040G-MD 的 OpenWrt 固件，适用于已刷 **Web U-Boot** 的机器，机型与上游 `bell_xg-040g-md` 相同。

基于 [xiangtailiang/OpenWrt-for-XG-040G-MD](https://github.com/xiangtailiang/OpenWrt-for-XG-040G-MD)，
源码 [xiangtailiang/openwrt](https://github.com/xiangtailiang/openwrt) `openwrt-25.12` 分支（内核 6.12），固定在上游固件编译时的版本。

## 特点

- 默认地址 `192.168.1.1`，主机名 `XG-040G-MD`，简体中文，Bootstrap 主题
- 定时重启（turboacc 暂时拿掉）
- 网口4（千兆）= WAN，网口1（2.5G）/2/3 = LAN（上游原本是 2.5G 当 WAN）；LuCI「网络 → 网口设置」图形化分配 LAN/WAN
- LED：WAN 连接/上线/掉线指示，可在「系统 → LED 配置」调整
- USB 硬盘 / U 盘：NTFS、exFAT、FAT32、ext4、HFS+、Btrfs，插上自动挂载
- USB 无线：RTL8822BU、RTL8821CU、MT7612U、AIC8800D80
- USB 有线：RTL8156B 2.5G
- 不带科学上网插件

详细改动见 [docs/tcboot-custom.md](docs/tcboot-custom.md)。

## 刷机

1. 先刷 Web U-Boot：参考 [XG-040G-MD 刷机教程](https://nwrt.kuroneko.host/flashdocs/XG-040G-MD.html)
2. 进入 U-Boot Web 恢复页面，上传 Release 里的 `*-bell_xg-040g-md-squashfs-factory.bin`
3. 以后升级用 `*-bell_xg-040g-md-squashfs-sysupgrade.bin`

> [!WARNING]
> 进入 U-Boot：通电约 **3 秒** 后再按住 reset 不放。
> **不要**先按住 reset 再通电，否则会进入底层救砖模式，进不了 U-Boot Web 界面。

## 编译

- 云编译：Actions → `Build_XG_040G_MD_tcboot` → Run workflow（推送相关文件到 main 也会自动触发）
- 本地：`bash scripts/build-tcboot-local.sh prepare && bash scripts/build-tcboot-local.sh build`
