# OpenWrt-K
![GitHub Repo stars](https://img.shields.io/github/stars/chenmozhijin/OpenWrt-K)
![GitHub forks](https://img.shields.io/github/forks/chenmozhijin/OpenWrt-K)
![GitHub commit activity (branch)](https://img.shields.io/github/commit-activity/t/chenmozhijin/OpenWrt-K)
![GitHub last commit (by committer)](https://img.shields.io/github/last-commit/chenmozhijin/OpenWrt-K)
![Workflow Status](https://github.com/chenmozhijin/OpenWrt-K/actions/workflows/build-openwrt.yml/badge.svg)
> OpenWRT软件包与固件自动云编译


## 固件介绍

1. 基于OpenWrt官方源码编译
2. 自带丰富的LuCI插件与软件包（见内置功能）
3. 自带SmartDNS+AdGuard Home配置（AdGuard Home 默认密码：password）
4. 随固件编译几乎全部kmod（无sfe），拒绝kernel版本不兼容（kmod在Releases allkmod.zip中，建议与固件一同下载)、
5. 固件自带OpenWrt-K工具支持升级官方源没有的软件包（使用```openwrt-k```命令）
6. 使用清华镜像源加快软件包下载
7. 提供多种格式固件以应对不同需求


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
+    [luci-app-openclash](https://github.com/vernesong/OpenClash):可运行在 OpenWrt 上的 Clash 客户端
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
+    luci-app-zerotier：ZeroTier虚拟局域网

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
+    [cloudflared](https://github.com/cloudflare/cloudflared)：Cloudflare 隧道客户端
</details>

+    LuCI主题：[Argon](https://github.com/jerrykuku/luci-theme-argon)

## 固件预览
<details>
 <summary>点击展开预览</summary>
 
### 概览:
![概览](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/1.webp)
### 新版netdata实时监控
![实时监控](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/2.webp)
### DiskMan 磁盘管理
![磁盘管理](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/3.webp)
### Argon 主题设置
![Argon 主题设置](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/4.webp)
### AdGuardHome广告屏蔽工具
![AdGuardHome](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/5.webp)
### SmartDNS DNS服务器
![SmartDNS](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/6.webp)
### 文件助手
![文件助手](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/7.webp)
### Socat网络工具
![概览](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/8.webp)
### Turbo ACC 网络加速
![概览](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/9.webp)
### ZeroTier虚拟局域网
![概览](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/10.webp)

</details>

## 定制编译 OpenWrt 固件
> 如果你有其他需求可以fork此仓库进行自定义

### 1.仓库基本结构
```
config  --- 存储openwrt编译配置
files   --- openwrt固件自定义文件
scripts --- 编译时所用的部分脚本
OpenWrt-K.Config --- 暂时仅用于定义openwrt编译所用的分支或tag（仅官方源）
config_build_tool.sh --- OpenWrt-k配置构建工具
```
### 2.编译流程
1. prepare：准备编译移植所需的源码与一些参数
2. build1: 修改部分源码按需添加openclash内核与AdGuardHome核心并编译工具链
3. build-package：编译固件所需的软件包
4. build-Image_Builder：编译Image_Builder与所有kmod（除sfe）
5. 使用4编译的Image Builderkmod添加3编译软件包（除kmod或许有sfe）与4编译的kmod（除sfe）构建镜像
+  注：3与4同时进行，拆成5个job是因为github限制一个job只能运行6小时软件包多点就超时了
 
### 3. 修改openwrt编译配置

#### 3.1修改openwrt编译所用的分支或tag
+ 直接修改OpenWrt-K.Config中```openwrt_tag/branche=```一行```=```后面的分支或tag
+ 注：建议使用较新的分支或tag（至少使用firewall4），paswall在v22.03.5中无法正常运行需升级dnsmasq与其依赖libubox（可参考[ce2e34e](https://github.com/chenmozhijin/OpenWrt-K/commit/ce2e34e88483f292451ae8078a44559218713d3e)被注释掉的部分）

#### 3.2修改openwrt固件编译配置
> 你可以手动修改config文件夹下的文件，但我建议使用OpenWrt-k配置构建工具
+ 因为：
1. 你可以使用构建系统配置接口（Menuconfig）
2. 能避免许多人为造成的错误
##### 使用OpenWrt-k配置构建工具

<details>
 <summary>点击展开工具图片</summary>
 
![OpenWrt-k配置构建工具](https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/img/01.webp)

</details>

###### 1. 准备环境：你需要准备一个linux系统并安装[依赖](https://openwrt.org/docs/guide-developer/toolchain/install-buildsystem#linux_gnu-linux_distributions)
###### 2. 下载工具
```
curl -O https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/config_build_tool.sh && chmod +x config_build_tool.sh
```
###### 3. 运行工具
```
./config_build_tool.sh
```
1. 填写openwrt编译所用的分支或tag
2. 填写你fork的openwrt-k编译仓库地址
3. 准备运行环境（请确保你拥有良好的网络环境）
4. 打开openwrt配置菜单自定义你的配置
5. 构建配置

###### 4. 上传
1. 先看看生成的配置文件有哪些
2. 删除fork仓库的config文件夹中刚刚未生成的配置文件（打开文件右上角三个点```Delete file```，请勿删除config/linux文件夹及其中的文件）
3. 上传覆盖刚刚生成的配置文件到config文件夹中

### 4. 运行编译工作流
> 此仓库在UTC 4：00及UTC+8 12：00自动运行，若不需要请删除[这两行](https://github.com/chenmozhijin/OpenWrt-K/blob/main/.github/workflows/build-openwrt.yml#LL27C1-L28C24)
1. 进入你fork的仓库
2. 点击上方的```"Actions"```
3. 点击左侧的```"Build OpenWrt-K"```（可能需要先开启GitHub Actions才能看到）
4. 然后点击```"Run workflow"```在点击绿色的```"Run workflow"```（可能需要先开启你fork的仓库GitHub Actions才能看到）
5. 刷新一下你将看到你运行的工作流，然后去做点别的是事过几个小时在来看看

### 5. 下载固件
> 请确保你工作流运行成功
1. 进入你fork的仓库的```"Code"```页面
2. 点击右侧的```"Releases"```
3. 下载你需要的镜像（校验信息在sha256sums中）

### 6.注意事项
1. 不建议编译sfe，如需编译请删除[此行](https://github.com/chenmozhijin/OpenWrt-K/blob/06af48fd0cdcc21525d96061fa65c111ae462c56/.github/workflows/build-openwrt.yml#LL438C11-L438C174)的注释并删除build-openwrt.yml中的所有
```
|sed 's/kmod-shortcut-fe-cm=m/kmod-shortcut-fe-cm=n/g'|sed 's/kmod-shortcut-fe=m/kmod-shortcut-fe=n/g' |sed 's/kmod-fast-classifier=m/kmod-fast-classifier=n/g'
```
2. 如需修改默认ip```192.168.1.1```可添加
```
uci set network.lan.ipaddr="192.168.2.1"
uci commit network
/etc/init.d/network restart
```
到/files/etc/uci-defaults/zzz-chenmozhijin的第二行
3.如果你fork了此仓库固件版本与页脚中的```Compiled by 沉默の金```会被修改为你的github名称可以在[settings/Public profile](https://github.com/settings/profile) Name一栏中修改

## 感谢
 感谢以下项目与各位制作软件包大佬的付出
 
+    [openwrt/openwrt](https://github.com/openwrt/openwrt/)
+    [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)
+    [Lienol/openwrt](https://github.com/Lienol/openwrt) 
+    [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt/)
+    [wongsyrone/lede-1](https://github.com/wongsyrone/lede-1)
+    [Github Actions](https://github.com/features/actions)
+    [softprops/action-gh-release](https://github.com/ncipollo/release-action)
+    [dev-drprasad/delete-older-releases](https://github.com/mknejp/delete-release-assets)
