# OpenWrt-K
![GitHub Repo stars](https://img.shields.io/github/stars/chenmozhijin/OpenWrt-K)
![GitHub forks](https://img.shields.io/github/forks/chenmozhijin/OpenWrt-K)
![GitHub commit activity (branch)](https://img.shields.io/github/commit-activity/t/chenmozhijin/OpenWrt-K)
![GitHub last commit (by committer)](https://img.shields.io/github/last-commit/chenmozhijin/OpenWrt-K)
![Workflow Status](https://github.com/chenmozhijin/OpenWrt-K/actions/workflows/build-openwrt.yml/badge.svg)
> OpenWRT软件包与固件自动云编译
## 目录
1. [固件介绍](https://github.com/chenmozhijin/OpenWrt-K#%E5%9B%BA%E4%BB%B6%E4%BB%8B%E7%BB%8D)
2. [固件使用方法](https://github.com/chenmozhijin/OpenWrt-K#%E5%9B%BA%E4%BB%B6%E4%BD%BF%E7%94%A8%E6%96%B9%E6%B3%95)
3. [定制编译 OpenWrt 固件](https://github.com/chenmozhijin/OpenWrt-K#%E5%AE%9A%E5%88%B6%E7%BC%96%E8%AF%91-openwrt-%E5%9B%BA%E4%BB%B6)
## 固件介绍

1. 基于OpenWrt官方源码编译
2. 自带丰富的LuCI插件与软件包（见内置功能）
3. 自带SmartDNS+AdGuard Home配置（AdGuard Home 默认密码：```password```）
4. 随固件编译几乎全部kmod（无sfe），拒绝kernel版本不兼容（kmod在Releases allkmod.zip中，建议与固件一同下载)、
5. 固件自带OpenWrt-K工具支持升级官方源没有的软件包（使用```openwrt-k```命令）
6. 使用清华镜像源加快软件包下载
7. 提供多种格式固件以应对不同需求


### 内置功能
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

<details>
 <summary>网卡驱动</summary>

+    kmod-8139cp
+    kmod-8139too
+    kmod-alx
+    kmod-amazon-ena
+    kmod-amd-xgbe
+    kmod-bnx2
+    kmod-bnx2x
+    kmod-e1000
+    kmod-e1000e
+    kmod-forcedeth
+    kmod-i40e
+    kmod-iavf
+    kmod-igb
+    kmod-igbvf
+    kmod-igc
+    kmod-ixgbe
+    kmod-libphy
+    kmod-macvlan
+    kmod-mii
+    kmod-mlx4-core
+    kmod-mlx5-core
+    kmod-net-selftests
+    kmod-pcnet32
+    kmod-phy-ax88796b
+    kmod-phy-realtek
+    kmod-phy-smsc
+    [kmod-r8125](https://github.com/sbwml/package_kernel_r8125)
+    kmod-r8152
+    kmod-r8168
+    kmod-tg3
+    kmod-tulip
+    kmod-via-velocity
+    kmod-vmxnet3
 
</details>



### 固件预览
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

## 固件使用方法
<details>
 <summary>点击展开使用方法</summary>

#### 1. 下载固件：
1. 点击右侧的```"Releases"```
2. 点击```"Show all xx assetss"```展开
3. 下载需要的固件（x86_64架构pve/exsi建议下载openwrt-x86-64-generic-squashfs-combined-efi.vmdk）
#### 2. 安装固件：
##### 1. pve安装
1. 点击创建虚拟机输入一个名称记下VMID点击下一步
2. 操作系统选项系统类别选```Linux```版本选```6.x - 2.6 Kernel```并选择```不使用任何介质```
3. 系统选项BIOS选```OVMF (UEFI)```，取消勾选```添加EFI磁盘```其他默认（如果下载的固件名不含```-efi```则默认即可）
4. 磁盘选项删除所有磁盘（磁盘一会直接上传）
5. CPU选项根据自己机器的性能选（这里的核心数应该是线程数）
6. 内存选项根据自己机器的性能选（一般1024mib或512mib）
7. 网络选项模型建议选```VMware vmxnet3```，因为半虚拟化在我这里丢包严重（访问nas中的图片图片都损坏）
8. 确认完成后将固件传送到pve的```/var/lib/vz/images/你刚记的VMID/```目录下，在终端输入
```
qm importdisk 你刚记的VMID "/var/lib/vz/images/你刚记的VMID/你下载的固件" local --format=qcow2
```
然后回车，你会发现你刚创建的虚拟机的硬件菜单下会多一个未使用的磁盘

9. 选中未使用的磁盘点上面的编辑在点添加
10. 点击选项菜单双击引导顺序，仅给刚添加的磁盘打勾然后点ok，现在你可以启动虚拟机了

### 2. 固件使用：
1. 进入openwrt web界面，一般访问```192.168.1.1```即可
>  注：此ip容易与光猫路由器冲突，这可能导致无法访问openwrt或互联网，你可以修改它们的ip或修改openwrt ip

2. 第一次访问没有密码直接登录即可，第一次开机会运行大量脚本建议开机后等几分钟在开始设置
3. 设置密码：访问[```系统/管理权```](http://192.168.1.1/cgi-bin/luci/admin/system/admin)中设置密码
5. 配置PPPoE：上网访问[```网络/接口```](http://192.168.1.1/cgi-bin/luci/admin/network/network)找到```wan```点编辑，协议选择```PPPoE```点```切换协议```输入```PAP/CHAP 用户名```与```PAP/CHAP 密码```再点击保存点击保存并应用即可
6. 配置lan口：访问[```网络/接口```](http://192.168.1.1/cgi-bin/luci/admin/network/network)点击上面的```设备```找到```br-lan```点配置，在网桥端口为你需要作为lan口的网口打勾再点击保存点击保存并应用即可
7. SmartDNS与AdGuardHome默认就是启用并设置好的（AdGuardHome默认密码：```password```），访问[```服务/AdGuard Home```](http://192.168.1.1/cgi-bin/luci/admin/services/AdGuardHome)点下面的更多选项选择```改变网页登录密码```点添加，找到改变网页登录密码输入密码后按载入计算模块然后计算最后点下面的保存并应用
8. 使用openclash：本固件中以默认将openclash的DNS设置设置为AdGuardHome如需使用openclash请将[```服务/AdGuard Home```](http://192.168.1.1/cgi-bin/luci/admin/services/AdGuardHome)中的1745重定向设置为```无```，并在订阅配置后在规则附加选项中全部点all找到有```代理规则(by 沉默の金)```的一项将策略组改为你代理用的策略组
9. 使用PassWall：本固件中以默认将PassWal的DNS设置为AdGuardHome，请不要修改DNS设置并保持[```服务/AdGuard Home```](http://192.168.1.1/cgi-bin/luci/admin/services/AdGuardHome)中的1745重定向设置为```作为dnsmasq的上游服务器```

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
5. 使用4编译的Image Builderkmod添加3编译软件包（除kmod）与4编译的kmod（除sfe）构建镜像
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
3. 点击```"Show all xx assetss"```展开（生成的文件较少则无此按钮）
4. 下载你需要的镜像（校验信息在sha256sums中）

### 6.注意事项
1. 不建议编译sfe，如需编译请删除
[build-openwrt.yml中```#cp $CMZJ_PATCH_ROOT_PATH/hack-$kernel_version/953-net-patch-linux-kernel-to-support-shortcut-fe.patch $OPENWRT_ROOT_PATH/target/linux/generic/hack-$kernel_version```](https://github.com/chenmozhijin/OpenWrt-K/blob/06af48fd0cdcc21525d96061fa65c111ae462c56/.github/workflows/build-openwrt.yml#LL438C11-L438C174)
的注释并删除build-openwrt.yml中的所有
```
|sed 's/kmod-shortcut-fe=m/kmod-shortcut-fe=n/g' 
```
与build-openwrt.yml中所有的
```
|sed 's/kmod-shortcut-fe-cm=m/kmod-shortcut-fe-cm=n/g'
```
或
```
|sed 's/kmod-fast-classifier=m/kmod-fast-classifier=n/g'
```
> 注:kmod-shortcut-fe-cm与kmod-fast-classifier无法同时编译，上面删除仅删除要编译的即可。
2. 如需修改默认ip```192.168.1.1```可将
```
uci set network.lan.ipaddr="192.168.2.1"
uci commit network
/etc/init.d/network restart
```
插入到/files/etc/uci-defaults/zzz-chenmozhijin的第二行

3. 如果你fork了此仓库，则编译出的固件的固件版本与页脚中的```Compiled by 沉默の金```中的沉默の金会被修改为你的github名称，你可以在[settings/Public profile](https://github.com/settings/profile) Name一栏中修改
4. 部分软件包对firewall4的兼容不是很好，不建议编译。具体列表见openwrt/openwrt#11614

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
