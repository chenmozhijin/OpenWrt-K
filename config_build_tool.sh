#!/usr/bin/env bash
#   Copyright (C) 2023  沉默の金

trap 'rm -rf "$TMPDIR"' EXIT
TMPDIR=$(mktemp -d)

function start() {
    install_dependencies
    if [ ! -e "buildconfig.config" ]; then
        input_parameters
    fi
    menu
    echo end
}

function install_dependencies() {
    which which||echo "请先安装which"
    echo "检测运行环境"
    if which apt-get &>/dev/null; then
    PM=apt
    fi
    if which yum &>/dev/null; then
    PM=yum
    fi
    n=0
    case $PM in
        apt)
            for package_name in build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev python3-distutils rsync unzip zlib1g-dev file wget make; do
            if [ "$(apt list --installed 2>/dev/null| grep -c "^${package_name}")" -eq '0' ];then
                if test ${n} = 0; then
                    echo $package_name > $TMPDIR/install.list
                    n=$(($n+1))
                else
                    sed -i "s/.*/&\ ${package_name}/g" $TMPDIR/install.list
                    n=$(($n+1))
                fi
            fi
            done
            ;;
        yum)
            for package_name in bzip2 gcc gcc-c++ git make ncurses-devel patch rsync tar unzip wget which diffutils python2 python3 perl-base perl-Data-Dumper perl-File-Compare perl-File-Copy perl-FindBin perl-IPC-Cmd perl-Thread-Queue; do
            if [ "$(yum list installed 2>/dev/null| grep -c "^${package_name}")" -eq '0' ];then
                if test ${n} = 0; then
                    echo $package_name > $TMPDIR/install.list
                    n=$(($n+1))
                else
                    sed -i "s/.*/&\ ${package_name}/g" $TMPDIR/install.list
                    n=$(($n+1))
                fi
            fi
            done
            ;;
        *)
            if ! (whiptail --title "Yes/No Box" --yes-button "我已安装全部依赖" --no-button "退出" --yesno "不支持自动安装依赖的系统，建议使用ubuntu或手动安装openwrt依赖。openwrt所需依赖见\nhttps://openwrt.org/docs/guide-developer/toolchain/install-buildsystem#linux_gnu-linux_distributions" 10 104) then
                exit 0
            fi
            ;;
        esac
    if [ -e "$TMPDIR/install.list" ]; then
        if (whiptail --title "Yes/No Box" --yes-button "安装" --no-button "退出" --yesno "是否安装$(cat $TMPDIR/install.list|sed "s/ /、/g")，它们是此脚本的依赖" 10 60) then
            source /etc/os-release
            case $PM in
            apt)
                sudo apt-get update || exit 0
                sudo apt-get install -y $(cat $TMPDIR/install.list)|| exit 0
                ;;
            yum)
                sudo yum install -y $(cat $TMPDIR/install.list)|| exit 0
                ;;
            *)
                echo "不支持的系统，建议使用ubuntu或手动安装"$(cat $TMPDIR/install.list)
                ;;
            esac
        else
            exit 0
        fi
    fi
}

function detect_github_api_rate_limit() {
remaining_requests=$(curl -s -i https://api.github.com/users/octocat|sed -n "/^x-ratelimit-remaining:/p"|sed "s/.*: //"| awk '{print int($0)}') || network_error
if [ "$remaining_requests" -lt "2" ]; then
    reset_time=$(date -d @$(curl -s -i https://api.github.com/users/octocat|sed -n "/^x-ratelimit-reset:/p"|sed "s/.*: //") +"%Y-%m-%d %H:%M:%S") || network_error
    echo "超出github的 API 速率限制,请等待到"$reset_time
fi
}

function input_parameters() {
    detect_github_api_rate_limit
    curl -s https://api.github.com/repos/openwrt/openwrt/tags|sed -n  '/^    "name": "/p'|sed -e 's/    "name": "//g' -e 's/",//g'> $TMPDIR/tagbranch.list || network_error
    curl -s https://api.github.com/repos/openwrt/openwrt/branches|sed -n  '/^    "name": "/p'|sed -e 's/    "name": "//g' -e 's/",//g'>> $TMPDIR/tagbranch.list || network_error
    latest_tag=$(curl -s https://api.github.com/repos/openwrt/openwrt/tags|sed -n  '/^    "name": "/p'|sed -e 's/    "name": "//g' -e 's/",//g'| sed -n '1p')
    inputbox="输入编译的OpenWrt branch或tag例如v23.05.0-rc1或master\nEnter the compiled OpenWrt branch or tag such as v23.05.0-rc1 or master"
    OPENWRT_TAG_BRANCHE=$(whiptail --title "choose tag/branch" --inputbox "$inputbox" 10 60 $latest_tag 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus != 0 ]; then
        echo "你选择了退出"
        exit 0
    fi
    while [ "$(grep -c "^${OPENWRT_TAG_BRANCHE}$" $TMPDIR/tagbranch.list)" -eq '0' ]; do
        whiptail --title "Message box" --msgbox "输入的OpenWrt branch或tag不存在,选择ok重新输入" 10 60
        OPENWRT_TAG_BRANCHE=$(whiptail --title "choose tag/branch" --inputbox "$inputbox" 10 60 $latest_tag 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            echo "你选择了退出"
            exit 0
        fi
    done
    inputbox="输入OpenWrt-K存储库地址"
    OpenWrt_K_url="$(whiptail --title "Enter the repository address" --inputbox "$inputbox" 10 60 https://github.com/chenmozhijin/OpenWrt-K 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        whiptail --title "Message box title" --msgbox "你选择的OpenWrt branch或tag为: $OPENWRT_TAG_BRANCHE\n选择的OpenWrt-K存储库地址为: $OpenWrt_K_url" 10 80
        echo OPENWRT_TAG_BRANCHE=$OPENWRT_TAG_BRANCHE > buildconfig.config
        echo OpenWrt_K_url=$OpenWrt_K_url >> buildconfig.config
    else
        echo "你选择了退出"
        exit 0
    fi
}

function network_error() {
    whiptail --title "Message box" --msgbox "获取最新OpenWrt branch与tag失败,请检查你的网络环境是否能正常与github通信。" 10 60
    exit 1
}

function menu() {
    OPTION=$(whiptail --title "OpenWrt-k配置构建工具" --menu "选择你要执行的步骤或选择Cancel退出" 15 60 8 \
    "1" "准备运行环境" \
    "2" "打开openwrt配置菜单" \
    "3" "构建配置" \
    "4" "载入OpenWrt-K默认config" \
    "5" "清除所有配置" \
    "6" "清除运行环境" \
    "7" "重新配置OpenWrt-K存储库地址与OpenWrt branch或tag" \
    "8" "关于" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ "$OPTION" = "1" ]; then
            if (whiptail --title "Yes/No Box" --yesno "这将会下载openwrt以及其插件的源码，请确保你拥有良好的网络环境。选择yes继续no返回菜单。" 10 60) then
                prepare
            else
                menu
            fi
        elif [ "$OPTION" = "7" ]; then
            input_parameters
            menu
        elif [ "$OPTION" = "8" ]; then
            about
        else  
            if [ "$(grep -c "^build_dir=" buildconfig.config)" -eq '1' ];then
                if [ -e "$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")/openwrt/feeds/telephony.index" ];then
                  case "${OPTION}" in
                    2)
                      menuconfig
                      ;;
                    3)
                        if  (whiptail --title "Yes/No Box" --yesno "这将会覆盖你已生成的配置。选择yes继续no返回菜单。" 10 60) then
                            build
                        else
                            menu
                        fi
                      ;;
                    4)
                        if  (whiptail --title "Yes/No Box" --yesno "这将会覆盖你的现有配置。选择yes继续no返回菜单。" 10 60) then
                            importopenwrt_kconfig
                        else
                            menu
                        fi
                        ;;
                    5)
                        if  (whiptail --title "Yes/No Box" --yesno "这将会删除你的现有配置。选择yes继续no返回菜单。" 10 60) then
                            clearconfig
                        else
                            menu
                        fi                      
                      ;;
                    6)
                        if  (whiptail --title "Yes/No Box" --yesno "这将会删除你未生成的配置与下载的文件。选择yes继续no返回菜单。" 10 60) then
                            clearrunningenvironment
                        else
                            menu
                        fi       
                      ;;
                    *)
                      echo "错误：未知的选项"
                      exit 1
                    esac
                else
                    if [ -e "$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")" ];then
                    sed -i "/^OpenWrt_K_dir=/d" buildconfig.config               
                    fi
                    whiptail --title "Message box" --msgbox "你还没有准备运行环境，选择ok以返回菜单。" 10 60
                    menu
                fi
            else
                whiptail --title "Message box" --msgbox "你还没有准备运行环境，选择ok以返回菜单。" 10 60
                menu
            fi
        fi
    else
        echo "你选择了退出"
        exit 0
    fi
}

function prepare() {
    mkdir -p OpenWrt-K_config_build_dir
    if [ "$(grep -c "^build_dir=" buildconfig.config)" -eq '1' ];then
        build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
        openwrt_dir=$build_dir/openwrt
        cd $build_dir
    else
        cd OpenWrt-K_config_build_dir
        build_dir=$(pwd)
        echo "build_dir=$build_dir" >> $build_dir/../buildconfig.config
        openwrt_dir=$build_dir/openwrt
    fi
    OpenWrt_K_url=$(grep "^OpenWrt_K_url=" $build_dir/../buildconfig.config|sed  "s/OpenWrt_K_url=//")
    OpenWrt_K_dir=$build_dir/$(echo $OpenWrt_K_url|sed -e "s/https:\/\///" -e "s/\/$//" -e "s/[.\/a-zA-Z0-9]\{1,111\}\///g")
    OPENWRT_TAG_BRANCHE=$(grep "^OPENWRT_TAG_BRANCHE=" $build_dir/../buildconfig.config|sed  "s/OPENWRT_TAG_BRANCHE=//")
    if [ -d "$OpenWrt_K_dir" ]; then
        git -C $OpenWrt_K_dir pull || download_failed
    else
        git clone $OpenWrt_K_url $OpenWrt_K_dir || download_failed
    fi
    if [ -d "$openwrt_dir" ]; then
        cd $openwrt_dir
        if ! [[ "$OPENWRT_TAG_BRANCHE" =~ ^v.* ]]; then
            git checkout $OPENWRT_TAG_BRANCHE || download_failed
            git -C $openwrt_dir pull || download_failed
        else
            if ! [[ "$(git branch |sed -n "/^\* /p"|sed "s/\* //")" =~ ^\(HEAD\ detached\ at\ v.* ]]; then
                git -C $openwrt_dir pull || download_failed
                git checkout $OPENWRT_TAG_BRANCHE || download_failed
            fi
        fi
    else
        git clone https://github.com/openwrt/openwrt $openwrt_dir
        cd $openwrt_dir
        git checkout $OPENWRT_TAG_BRANCHE || download_failed
    fi
    if [ -d "$openwrt_dir/package/chenmozhijin-package" ]; then    
        git -C $openwrt_dir/package/chenmozhijin-package pull || download_failed
    else
        git clone https://github.com/chenmozhijin/chenmozhijin-package $openwrt_dir/package/chenmozhijin-package || download_failed
    fi
    cd $openwrt_dir
    ./scripts/feeds update -a  || download_failed
    ./scripts/feeds install -a
    [[ -d $openwrt_dir ]] && rm -rf .config
    cat $OpenWrt_K_dir/config/target.config >> .config
    cat $OpenWrt_K_dir/config/luci.config >> .config
    cat $OpenWrt_K_dir/config/utilities.config >> .config
    cat $OpenWrt_K_dir/config/network.config >> .config
    cat $OpenWrt_K_dir/config/other.config >> .config
    cat $OpenWrt_K_dir/config/kmod.config >> .config
    cat $OpenWrt_K_dir/config/image.config >> .config
    make defconfig
    cd $build_dir/..	
    whiptail --title "Message box" --msgbox "准备完成，选择ok以返回菜单。" 10 60
    menu
}

function download_failed() {
    whiptail --title "Message box" --msgbox "下载失败,请检查你的网络环境是否正常与OpenWrt-K存储库地址是否正确。" 10 60
    menu
}

function menuconfig() {
    build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
    if (whiptail --title "Yes/No Box" --yesno "你是否要修改openwrt的TARGET配置？（若未修改存储库则默认为x86_64）" 10 60) then
        targetconfig
    else
        echo "You chose No. Exit status was $?."
    fi
    cd $build_dir/openwrt
    make menuconfig
    cd $build_dir/..
    menu

}

function targetconfig() {
    build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
    openwrt_dir=$build_dir/openwrt
    [[ -d $TMPDIR/targetconfig ]] && rm -rf $TMPDIR/targetconfig
    mkdir -p $TMPDIR/targetconfig
    targetconfigpath=$TMPDIR/targetconfig/
    targetdiffconfig=$targetconfigpath/diff.config
    notargetdiffconfig=$targetconfigpath/notargetdiff.config
    cd $openwrt_dir
    ./scripts/diffconfig.sh > $targetdiffconfig
    TARGET=$(sed -n  "/^CONFIG_TARGET_[a-zA-Z0-9]\{1,15\}=y$/p" $targetdiffconfig | sed -e 's/CONFIG_TARGET_//'  -e 's/=y//')
    sed "/^CONFIG_TARGET_${TARGET}.*/d" $targetdiffconfig > $notargetdiffconfig
    sed -i "/^CONFIG_TARGET_MULTI_PROFILE=y$/d" $notargetdiffconfig
    sed -i "/^CONFIG_TARGET_DEVICE_${TARGET}.*/d" $notargetdiffconfig
    sed -i "/^# CONFIG_TARGET_DEVICE_${TARGET}.*/d" $notargetdiffconfig
    sed -i "/^CONFIG_TARGET_DEVICE_PACKAGES_${TARGET}.*/d" $notargetdiffconfig
    sed -i "/^CONFIG_TARGET_PER_DEVICE_ROOTFS=y$/d" $notargetdiffconfig
    sed -i "/^CONFIG_TARGET_ALL_PROFILES=y$/d" $notargetdiffconfig
    whiptail --title "Message box" --msgbox "点击ok后，请仅修改TARGET配置然后保存退出，请勿修改其他配置或修改保存的目录与文件名" 10 60
    cd $build_dir/openwrt
    make menuconfig
    cat $notargetdiffconfig >> $openwrt_dir/.config
    make defconfig
    [[ -d $TMPDIR/targetconfig ]] && rm -rf $TMPDIR/targetconfig
    cd $build_dir/..
}

function importopenwrt_kconfig() {
    build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
    openwrt_dir=$build_dir/openwrt
    OpenWrt_K_url=$(grep "^OpenWrt_K_url=" $build_dir/../buildconfig.config|sed  "s/OpenWrt_K_url=//")
    OpenWrt_K_dir=$build_dir/$(echo $OpenWrt_K_url|sed -e "s/https:\/\///" -e "s/\/$//" -e "s/[.\/a-zA-Z0-9]\{1,111\}\///g")
    cd $openwrt_dir
    [[ -d $openwrt_dir ]] && rm -rf .config
    cat $OpenWrt_K_dir/config/target.config >> .config
    cat $OpenWrt_K_dir/config/luci.config >> .config
    cat $OpenWrt_K_dir/config/utilities.config >> .config
    cat $OpenWrt_K_dir/config/network.config >> .config
    cat $OpenWrt_K_dir/config/other.config >> .config
    cat $OpenWrt_K_dir/config/kmod.config >> .config
    cat $OpenWrt_K_dir/config/image.config >> .config
    make defconfig
    cd $build_dir/..
    menu
}

function clearconfig() {
    build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
    openwrt_dir=$build_dir/openwrt
    [[ -d $openwrt_dir ]] && rm -rf $openwrt_dir/tmp
    [[ -d $openwrt_dir ]] && rm -rf $openwrt_dir/.config
    [[ -d $openwrt_dir ]] && rm -rf $openwrt_dir/.config.old
    cd $openwrt_dir
    make defconfig
    cd $build_dir/..
    menu
}

function clearrunningenvironment() {
    build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
    cd $build_dir/..
    rm -rf $build_dir
    sed -i  "/^build_dir=/d" buildconfig.config
    menu
}

function about() {
    whiptail --title "关于" --msgbox "这是一个用于生成OpenWrt-K config文件夹中配置文件的脚本\n\
    Copyright (C) 2023  沉默の金, All rights reserved.\n" 10 60
    menu
}

function build () {
    #准备工作
    build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
    openwrt_dir=$build_dir/openwrt
    [[ -d $TMPDIR/buildconfig ]] && rm -rf $TMPDIR/buildconfig
    [[ -d $TMPDIR/output ]] && rm -rf $TMPDIR/output
    mkdir -p $TMPDIR/buildconfig
    mkdir -p $TMPDIR/output
    buildconfigdir=$TMPDIR/buildconfig
    outputdir=$TMPDIR/output
    cp $openwrt_dir/.config $buildconfigdir/original.config
    cd $openwrt_dir
    ./scripts/diffconfig.sh >> $buildconfigdir/diffconfig.config
    cd $buildconfigdir
    #修改未设置样式，生成仅注释文件
    sed -e '/^#/s/ is not set/=n/g' -e '/=n/s/# //g' diffconfig.config > diffconfig1.config
    sed -e '/^[a-zA-Z0-9]/s/.*//' -e '/^# CONFIG\_/s/.*//' original.config > note.config
    #将diffconfig中的内容插入仅注释文件中生成diffconfig2.config
    cp -f note.config  diffconfig2.config
    diffconfig_row=$(wc -l diffconfig.config | sed 's/ .*//') #原diffconfig行数
    line=1
    echo diffconfig_row=$diffconfig_row
    until [ "$line" -eq $(($diffconfig_row+1)) ]; do
        #echo $line $(sed -n "/$(sed -n "${line}p" diffconfig.config)/=" original.config) $(sed -n "${line}p" diffconfig1.config)
        sed -i "$(sed -n "/$(sed -n "${line}p" diffconfig.config)/=" original.config)c $(sed -n "${line}p" diffconfig1.config)" diffconfig2.config
        line=$(($line+1))
    done
    sed -i '/^$/d' diffconfig2.config #删除空行
    #清理不包含配置的注释
    sed -i ':label;N;s/#\n# Configuration\n#\n# end of Configuration//;b label' diffconfig2.config
    sed -i '/^$/d' diffconfig2.config
    for ((i=1; i<=3; i++)); do #重复三次
    sed -n '/^# end of/p' diffconfig2.config | sed -e "s/# end of //g" -e "s?/?\\\/?g"  > end.list
    endlist_row=$(wc -l end.list | sed 's/ .*//') #统计剩余注释集数量
    echo endlist_row=$endlist_row
    line=1
    until [ "$line" -eq $(($endlist_row+1)) ]; do
        #echo $line $(sed -n "${line}p" end.list)
        sed -i ":label;N;s/#\n# $(sed -n "${line}p" end.list)\n#\n# end of $(sed -n "${line}p" end.list)//;b label" diffconfig2.config
        line=$(($line+1))
    done
    sed -i '/^$/d' diffconfig2.config #删除空行
    done
    #将配置分类
    if [ "$(grep -c "# Target Images$" diffconfig2.config)" -ne '0' ];then
      sed -n "$(($(sed -n "/# Target Images$/=" diffconfig2.config)-1)),$(sed -n "/# end of Target Images$/=" diffconfig2.config)p" diffconfig2.config > $outputdir/image.config
      sed -i "$(($(sed -n "/# Target Images$/=" diffconfig2.config)-1)),$(sed -n "/# end of Target Images$/=" diffconfig2.config)d" diffconfig2.config
    else
      echo "没有Target Images配置"
      echo "" > image.config
    fi
    if [ "$(grep -c "# Kernel modules$" diffconfig2.config)" -ne '0' ];then
      sed -n "$(($(sed -n "/# Kernel modules$/=" diffconfig2.config)-1)),$(sed -n "/# end of Kernel modules$/=" diffconfig2.config)p" diffconfig2.config > $outputdir/kmod.config
      sed -i "$(($(sed -n "/# Kernel modules$/=" diffconfig2.config)-1)),$(sed -n "/# end of Kernel modules$/=" diffconfig2.config)d" diffconfig2.config
    else
      echo "没有Kernel modules配置"
      echo "" > kmod.config
    fi
    if [ "$(grep -c "# LuCI$" diffconfig2.config)" -ne '0' ];then
      sed -n "$(($(sed -n "/# LuCI$/=" diffconfig2.config)-1)),$(sed -n "/# end of LuCI$/=" diffconfig2.config)p" diffconfig2.config > $outputdir/luci.config
      sed -i "$(($(sed -n "/# LuCI$/=" diffconfig2.config)-1)),$(sed -n "/# end of LuCI$/=" diffconfig2.config)d" diffconfig2.config
    else
      echo "没有LuCI配置"
      echo "" > luci.config
    fi
    if [ "$(grep -c "# Network$" diffconfig2.config)" -ne '0' ];then
      sed -n "$(($(sed -n "/# Network$/=" diffconfig2.config)-1)),$(sed -n "/# end of Network$/=" diffconfig2.config)p" diffconfig2.config > $outputdir/network.config
      sed -i "$(($(sed -n "/# Network$/=" diffconfig2.config)-1)),$(sed -n "/# end of Network$/=" diffconfig2.config)d" diffconfig2.config
    else
      echo "没有Network配置"
      echo "" > network.config
    fi
    if [ "$(grep -c "# Utilities$" diffconfig2.config)" -ne '0' ];then
      sed -n "$(($(sed -n "/# Utilities$/=" diffconfig2.config)-1)),$(sed -n "/# end of Utilities$/=" diffconfig2.config)p" diffconfig2.config > $outputdir/utilities.config
      sed -i "$(($(sed -n "/# Utilities$/=" diffconfig2.config)-1)),$(sed -n "/# end of Utilities$/=" diffconfig2.config)d" diffconfig2.config
    else
      echo "没有Utilities配置"
      echo "" > utilities.config
    fi
    if [ "$(grep -c "^CONFIG_TARGET_[a-zA-Z0-9]\{1,15\}=y$" diffconfig2.config)" -ne '0' ];then
      sed -n "/^CONFIG_TARGET_$(sed -n  "/^CONFIG_TARGET_[a-zA-Z0-9]\{1,15\}=y$/p" diffconfig2.config | sed -e 's/CONFIG_TARGET_//'  -e 's/=y//').*/p" diffconfig2.config > $outputdir/target.config
      sed -i "/^CONFIG_TARGET_$(sed -n  "/^CONFIG_TARGET_[a-zA-Z0-9]\{1,15\}=y$/p" diffconfig2.config | sed -e 's/CONFIG_TARGET_//'  -e 's/=y//').*/d" diffconfig2.config
      if [ "$(grep -c "^CONFIG_TARGET_MULTI_PROFILE=y$" diffconfig2.config)" -ne '0' ];then
        sed -n "/^CONFIG_TARGET_MULTI_PROFILE=y$/p" diffconfig2.config >> $outputdir/target.config
        sed -i "/^CONFIG_TARGET_MULTI_PROFILE=y$/d" diffconfig2.config
        if [ "$(grep -c "# Target Devices$" diffconfig2.config)" -ne '0' ];then
          sed -n "$(($(sed -n "/# Target Devices$/=" diffconfig2.config)-1)),$(sed -n "/# end of Target Devices$/=" diffconfig2.config)p" diffconfig2.config >> $outputdir/target.config
          sed -i "$(($(sed -n "/# Target Devices$/=" diffconfig2.config)-1)),$(sed -n "/# end of Target Devices$/=" diffconfig2.config)d" diffconfig2.config
        else
          echo "没有Target Devices配置"
        fi
      else
        echo "没有使用Multiple devices配置"
      fi
    else
      echo "没有Target配置"
    fi
    cat diffconfig2.config > $outputdir/other.config
    #输出
    [[ -d $build_dir/../config/ ]] && rm -rf $build_dir/../config/
    mkdir -p $build_dir/../config/
    cp $outputdir/* $build_dir/../config/
    cd $build_dir/../config/
    whiptail --title "成功" --msgbox "OpenWrt-K配置文件构建完成\n\
    输出目录：$(pwd)\n\
    如果你修改了OpenWrt branch或tag请在OpenWrt-K.Config做相应修改\n\
    其他生成的配置文件请在config文件夹做相应修改\n\
    选择ok以返回菜单" 13 90
    cd $build_dir/..
    menu
}

start
