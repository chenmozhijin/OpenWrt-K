# OpenWrt-K

## 介绍

1. 基于OpenWrt官方源码编译
2. 自带丰富的OpenWrt原版LuCI插件从及Lienol与lede移植的LuCI插件
3. 提供多种格式固件应对安装到不同虚拟机/实体机的需求
4. 自带SmartDNS+AdGuard Home配置无需额外配置（AdGuard Home 默认密码：password）
5. 使用清华镜像源加快软件包下载

## 内置功能
已内置以下LuCI插件：
+    [luci-app-adguardhome](https://github.com/rufengsuixing/luci-app-adguardhome)
+    [luci-app-argon-config](https://github.com/jerrykuku/luci-app-argon-config)
+    luci-app-aria2
+    luci-app-cifs-mount
+    luci-app-ddns
+    luci-app-diag-core
+    [luci-app-diskman](https://github.com/lisaac/luci-app-diskman)
+    luci-app-dockerman
+    luci-app-fileassistant
+    luci-app-firewall
+    [luci-app-netdata](https://github.com/sirpdboy/luci-app-netdata)
+    [luci-app-netspeedtest](https://github.com/sirpdboy/netspeedtest)
+    luci-app-nlbwmon
+    luci-app-opkg
+    [luci-app-passwall](https://github.com/xiaorouji/openwrt-passwall/tree/luci)
+    [luci-app-passwall2](https://github.com/xiaorouji/openwrt-passwall2)
+    luci-app-rclone
+    luci-app-samba4
+    [luci-app-serverchan](https://github.com/tty228/luci-app-serverchan)
+    [luci-app-smartdns](https://github.com/pymumu/luci-app-smartdns)
+    luci-app-socat
+    luci-app-ttyd
+    [luci-app-turboacc](https://github.com/chenmozhijin/turboacc)
+    luci-app-upnp
+    luci-app-usb-printer
+    luci-app-vlmcsd
+    luci-app-webadmin
+    luci-app-wireguard
+    luci-app-wol
+    luci-app-zerotier
+    内置的LuCI主题：[Argon](https://github.com/jerrykuku/luci-theme-argon)

随固件编译的插件：
+    luci-app-baidupcs-web
+    luci-app-qbittorrent
+    luci-app-transmission

## 固件预览

### 内置功能/turboacc:
![内置功能/turboacc](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/1.png)

## 感谢
 感谢以下项目
 
+    [openwrt/openwrt](https://github.com/openwrt/openwrt/)
+    [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)
+    [Lienol/openwrt](https://github.com/Lienol/openwrt) 
+    [wongsyrone/lede-1](https://github.com/wongsyrone/lede-1)
+    [Github Actions](https://github.com/features/actions)
+    [softprops/action-gh-release](https://github.com/ncipollo/release-action)
+    [dev-drprasad/delete-older-releases](https://github.com/mknejp/delete-release-assets)
