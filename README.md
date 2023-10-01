# OpenWrt-K

[![GitHub Repo stars](https://img.shields.io/github/stars/chenmozhijin/OpenWrt-K)](https://github.com/chenmozhijin/OpenWrt-K/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/chenmozhijin/OpenWrt-K)](https://github.com/chenmozhijin/OpenWrt-K/forks?include=active%2Carchived%2Cinactive%2Cnetwork&page=1&period=2y&sort_by=stargazer_counts)
[![GitHub commit activity (branch)](https://img.shields.io/github/commit-activity/t/chenmozhijin/OpenWrt-K)](https://github.com/chenmozhijin/OpenWrt-K/commits)
[![GitHub last commit (by committer)](https://img.shields.io/github/last-commit/chenmozhijin/OpenWrt-K)](https://github.com/chenmozhijin/OpenWrt-K/commits)
[![Workflow Status](https://github.com/chenmozhijin/OpenWrt-K/actions/workflows/build-openwrt.yml/badge.svg)](https://github.com/chenmozhijin/OpenWrt-K/actions)
> OpenWRT软件包与固件自动云编译

## 目录

[README](https://github.com/chenmozhijin/OpenWrt-K#openwrt-k):

1. [固件介绍](https://github.com/chenmozhijin/OpenWrt-K#%E5%9B%BA%E4%BB%B6%E4%BB%8B%E7%BB%8D)
2. [更新日志](https://github.com/chenmozhijin/OpenWrt-K#%E6%9B%B4%E6%96%B0%E6%97%A5%E5%BF%97)  
  
[Wiki页面](https://github.com/chenmozhijin/OpenWrt-K/wiki):

1. [固件使用方法](https://github.com/chenmozhijin/OpenWrt-K/wiki/%E5%9B%BA%E4%BB%B6%E4%BD%BF%E7%94%A8%E6%96%B9%E6%B3%95)
2. [仓库基本介绍](https://github.com/chenmozhijin/OpenWrt-K/wiki/%E4%BB%93%E5%BA%93%E5%9F%BA%E6%9C%AC%E4%BB%8B%E7%BB%8D)
3. [定制编译OpenWrt固件](https://github.com/chenmozhijin/OpenWrt-K/wiki/%E5%AE%9A%E5%88%B6%E7%BC%96%E8%AF%91-OpenWrt-%E5%9B%BA%E4%BB%B6)
4. [常见问题](https://github.com/chenmozhijin/OpenWrt-K/wiki/%E5%B8%B8%E8%A7%81%E9%97%AE%E9%A2%98)

## 固件介绍

1. 基于OpenWrt官方源码编译
2. 自带丰富的LuCI插件与软件包（见内置功能）
3. 自带SmartDNS+AdGuard Home配置（AdGuard Home 默认密码：```password```）
4. 随固件编译几乎全部kmod（无sfe），拒绝kernel版本不兼容(kmod在Releases allkmod.zip中，建议与固件一同下载)
5. 固件自带OpenWrt-K工具支持升级官方源没有的软件包（使用```openwrt-k```命令）
6. 提供多种格式固件以应对不同需求

### 内置功能

已内置以下软件包：

1. LuCI插件：  
  [luci-app-adguardhome](https://github.com/chenmozhijin/luci-app-adguardhome) :AdGuardHome广告屏蔽工具的luci设置界面  
  [luci-app-argon-config](https://github.com/jerrykuku/luci-app-argon-config):Argon 主题设置  
  luci-app-aria2：aria2下载器  
  luci-app-cifs-mount：SMB/CIFS 网络挂载共享客户端  
  luci-app-ddns：动态 DNS  
  [luci-app-diskman](https://github.com/lisaac/luci-app-diskman)：DiskMan 磁盘管理  
  luci-app-fileassistant：文件助手  
  luci-app-firewall：防火墙  
  luci-app-netdata：[Netdata](https://github.com/netdata/netdata) 实时监控  
  [luci-app-netspeedtest](https://github.com/sirpdboy/netspeedtest)：网速测试  
  luci-app-nlbwmon：网络带宽监视器  
  luci-app-opkg：软件包  
  [luci-app-openclash](https://github.com/vernesong/OpenClash):可运行在 OpenWrt 上的 Clash 客户端  
  [luci-app-passwall](https://github.com/xiaorouji/openwrt-passwall/tree/luci)：passwall  
  [luci-app-passwall2](https://github.com/xiaorouji/openwrt-passwall2)：passwall2  
  luci-app-rclone：Rclone命令行网盘工具设置界面  
  luci-app-samba4：samba网络共享  
  [luci-app-smartdns](https://github.com/pymumu/luci-app-smartdns)：SmartDNS 服务器  
  [luci-app-socat](https://github.com/chenmozhijin/luci-app-socat)：Socat网络工具  
  luci-app-ttyd：ttyd 终端  
  [luci-app-turboacc](https://github.com/chenmozhijin/turboacc)：Turbo ACC 网络加速  
  luci-app-upnp：通用即插即用（UPnP）  
  luci-app-usb-printer：USB 打印服务器  
  luci-app-vlmcsd：KMS 服务器  
  luci-app-webadmin：Web 管理页面设置  
  [luci-app-wechatpush](https://github.com/tty228/luci-app-wechatpush)：微信推送  
  luci-app-wireguard：WireGuard 状态  
  luci-app-wol：网络唤醒  
  luci-app-zerotier：ZeroTier虚拟局域网

2. 其他部分软件包：  
  ethtool-full：网卡工具用于查询及设置网卡参数  
  sudo：sudo命令支持  
  htop：系统监控与进程管理软件  
  ipv6helper： ipv6-helper 脚本  
  cfdisk：磁盘分区工具  
  bc：一个命令行计算器  
  coremark：cpu跑分测试  
  pciutils：PCI 设备配置工具  
  usbutils：USB 设备列出工具  
  [cloudflared](https://github.com/cloudflare/cloudflared)：Cloudflare 隧道客户端

3. LuCI主题：[Argon](https://github.com/jerrykuku/luci-theme-argon)

    > + 以上软件包都在生成在Releases的package.zip文件中，可安装使用。

4. 网卡驱动：  
  kmod-8139cp  
  kmod-8139too  
  kmod-alx  
  kmod-amazon-ena  
  kmod-amd-xgbe  
  kmod-bnx2  
  kmod-bnx2x  
  kmod-e1000  
  kmod-e1000e  
  kmod-forcedeth  
  kmod-i40e  
  kmod-iavf  
  kmod-igb  
  kmod-igbvf  
  kmod-igc  
  kmod-ixgbe  
  kmod-libphy  
  kmod-macvlan  
  kmod-mii  
  kmod-mlx4-core  
  kmod-mlx5-core  
  kmod-net-selftests  
  kmod-pcnet32  
  kmod-phy-ax88796b  
  kmod-phy-realtek  
  kmod-phy-smsc  
  [kmod-r8125](https://github.com/sbwml/package_kernel_r8125)  
  kmod-r8152  
  kmod-r8168  
  kmod-tg3  
  kmod-tulip  
  kmod-via-velocity  
  kmod-vmxnet3

### 固件预览

#### 概览

![概览](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/1.webp)

#### 新版netdata实时监控

![实时监控](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/2.webp)

#### DiskMan 磁盘管理

![磁盘管理](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/3.webp)

#### Argon 主题设置

![Argon 主题设置](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/4.webp)

#### AdGuardHome广告屏蔽工具

![luci-app-adguardhome](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/5.webp)
![AdGuardHome](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/11.webp)

#### SmartDNS DNS服务器

![SmartDNS](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/6.webp)

#### 文件助手

![文件助手](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/7.webp)

#### Socat网络工具

![概览](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/8.webp)

#### Turbo ACC 网络加速

![概览](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/9.webp)

#### ZeroTier虚拟局域网

![概览](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/10.webp)

## 更新日志

2023.7.27： 添加多配置编译支持、移动README部分内容到wiki

## 感谢

 感谢以下项目与各位制作软件包大佬的付出

+ [openwrt/openwrt](https://github.com/openwrt/openwrt/)
+ [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)
+ [Lienol/openwrt](https://github.com/Lienol/openwrt)
+ [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt/)
+ [wongsyrone/lede-1](https://github.com/wongsyrone/lede-1)
+ [Github Actions](https://github.com/features/actions)
+ [softprops/action-gh-release](https://github.com/ncipollo/release-action)
+ [dev-drprasad/delete-older-releases](https://github.com/mknejp/delete-release-assets)
