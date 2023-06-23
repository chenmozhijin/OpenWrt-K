# OpenWrt-K
![GitHub Repo stars](https://img.shields.io/github/stars/chenmozhijin/OpenWrt-K)
![GitHub forks](https://img.shields.io/github/forks/chenmozhijin/OpenWrt-K)
![GitHub commit activity (branch)](https://img.shields.io/github/commit-activity/t/chenmozhijin/OpenWrt-K)
![GitHub last commit (by committer)](https://img.shields.io/github/last-commit/chenmozhijin/OpenWrt-K)
![Workflow Status](https://github.com/chenmozhijin/OpenWrt-K/actions/workflows/build-openwrt.yml/badge.svg)


## 介绍

1. 基于OpenWrt官方源码编译
2. 自带丰富的OpenWrt原版LuCI插件从及Lienol、immortalwrt与lede移植的LuCI插件
3. 提供多种格式固件应对安装到不同虚拟机/实体机的需求
4. 自带SmartDNS+AdGuard Home配置无需额外配置（AdGuard Home 默认密码：password）
5. 使用清华镜像源加快软件包下载
6. 随固件编译几乎全部kmod（无sfe），拒绝kernel 版本不兼容（kmod在OpenWrt-K_Vxx.xx.xx-xx-package allkmod.zip中需要时安装即可)


## 内置功能
已内置以下软件包：
<details>
 <summary>LuCI插件</summary>

+    [luci-app-adguardhome](https://github.com/rufengsuixing/luci-app-adguardhome) :AdGuardHome广告屏蔽工具的luci设置界面
+    [luci-app-argon-config](https://github.com/jerrykuku/luci-app-argon-config):Argon 主题设置
+    luci-app-aria2：aria2下载器
+    luci-app-cifs-mount：SMB/CIFS 网络挂载共享客户端
+    luci-app-ddns：动态 DNS
+    [luci-app-diskman](https://github.com/lisaac/luci-app-diskman)：DiskMan 磁盘管理
+    luci-app-fileassistant：文件助手
+    luci-app-firewall：防火墙 
+    luci-app-netdata：[Netdata](https://github.com/netdata/netdata) 实时监控
+    [luci-app-netspeedtest](https://github.com/sirpdboy/netspeedtest)：网速测试
+    luci-app-nlbwmon：网络带宽监视器
+    luci-app-opkg：软件包
+    [luci-app-passwall](https://github.com/xiaorouji/openwrt-passwall/tree/luci)：passwall
+    [luci-app-passwall2](https://github.com/xiaorouji/openwrt-passwall2)：passwall2
+    luci-app-rclone：Rclone命令行网盘工具设置界面
+    luci-app-samba4：samba网络共享
+    [luci-app-smartdns](https://github.com/pymumu/luci-app-smartdns)：SmartDNS 服务器
+    [luci-app-socat](https://github.com/chenmozhijin/luci-app-socat)：Socat网络工具
+    luci-app-ttyd：ttyd 终端
+    [luci-app-turboacc](https://github.com/chenmozhijin/turboacc)：Turbo ACC 网络加速
+    luci-app-upnp：通用即插即用（UPnP）
+    luci-app-usb-printer：USB 打印服务器
+    luci-app-vlmcsd：KMS 服务器
+    luci-app-webadmin：Web 管理页面设置
+    [luci-app-wechatpush](https://github.com/tty228/luci-app-wechatpush)：微信推送
+    luci-app-wireguard：WireGuard 状态
+    luci-app-wol：网络唤醒
+    luci-app-zerotier：ZeroTier虚拟局域网 VPN

</details>
<details>
 <summary>其他部分软件包</summary>

+    ethtool-full：网卡工具用于查询及设置网卡参数
+    sudo：sudo命令支持
+    htop：系统监控与进程管理软件
+    ipv6helper： ipv6-helper 脚本
+    cfdisk：磁盘分区工具
+    bc：一个命令行计算器
+    coremark：cpu跑分测试
+    pciutils：PCI 设备配置工具
+    usbutils：USB 设备列出工具
</details>

+    LuCI主题：[Argon](https://github.com/jerrykuku/luci-theme-argon)

## 固件预览

### 内置功能/turboacc:
<details>
 <summary> </summary>

![内置功能/turboacc](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/1.png)

</details>

## 感谢
 感谢以下项目与各位大佬的付出
 
+    [openwrt/openwrt](https://github.com/openwrt/openwrt/)
+    [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)
+    [Lienol/openwrt](https://github.com/Lienol/openwrt) 
+    [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt/)
+    [wongsyrone/lede-1](https://github.com/wongsyrone/lede-1)
+    [Github Actions](https://github.com/features/actions)
+    [softprops/action-gh-release](https://github.com/ncipollo/release-action)
+    [dev-drprasad/delete-older-releases](https://github.com/mknejp/delete-release-assets)
