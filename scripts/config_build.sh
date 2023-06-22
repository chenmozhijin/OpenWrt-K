#!/bin/bash
#Copyright (c) 2023 沉默の金
action=$1

function help() {
    echo "Commands: "
    echo "  prepare             准备运行环境"
    echo "  menuconfig          打开openwrt配置菜单"
    echo "  build               构建配置"
    echo "  importconfig        载入OpenWrt-K默认config(不载入target,保持你配置的)"
    echo "  clearconfig         清除所有配置(包括OpenWrt-K默认config)"
    echo "  clear               清除运行环境"
}

function clearall() {
    rm -rf $build_dir
}

function mkbuilddir() {
    if test $(echo "a${build_dir}a") != "aa"; then
        cd $build_dir/..
    fi
    mkdir -p OpenWrt-K_config_build_dir
    cd OpenWrt-K_config_build_dir
    build_dir=$(pwd)
}

function clone() {
    cd $build_dir
    git clone https://github.com/chenmozhijin/OpenWrt-K || update_OpenWrt-K
    git clone https://github.com/chenmozhijin/chenmozhijin-package || update_chenmozhijin-package
    git clone https://github.com/openwrt/openwrt/ || update_openwrt
    cd openwrt
    git checkout $(sed -n '/openwrt_tag\/branche/p' $build_dir/OpenWrt-K/OpenWrt-K.Config | sed -e 's/.*=//')
}

function update_OpenWrt-K() {
    cd $build_dir
    cd OpenWrt-K
    git pull
    cd $build_dir
}

function update_chenmozhijin-package() {
    cd $build_dir
    cd chenmozhijin-package
    git pull
    cd $build_dir
}

function update_openwrt() {
    cd $build_dir
    cd openwrt
    git pull
    cd $build_dir
}

function load_chenmozhijin-package() {
    cd $build_dir
    mv chenmozhijin-package openwrt/package/
}

function debug() {
    cd $build_dir/openwrt
    sed -i 's/-full//' ./include/target.mk 
    sed -i 's/dnsmasq/dnsmasq-full/g' ./include/target.mk 
}

function feeds() {
    cd $build_dir/openwrt
    ./scripts/feeds update -a 
    ./scripts/feeds install -a
}

function Import_config() {
    cd $build_dir/openwrt
    rm -rf .config
    cat $build_dir/OpenWrt-K/config/target.config >> .config
    cat $build_dir/OpenWrt-K/config/luci.config >> .config
    cat $build_dir/OpenWrt-K/config/utilities.config >> .config
    cat $build_dir/OpenWrt-K/config/network.config >> .config
    cat $build_dir/OpenWrt-K/config/other.config >> .config
    cat $build_dir/OpenWrt-K/config/kmod.config >> .config
    cat $build_dir/OpenWrt-K/config/image.config >> .config
    make defconfig
}

function Import_config_notarget() {
    mkdir -p configtmp
    cd $build_dir/openwrt || prepare
    cd $build_dir/openwrt
    ./scripts/diffconfig.sh > $build_dir/configtmp/diffconfig.config
    rm -rf .config
    sed '/^CONFIG_TARGET_/p' $build_dir/configtmp/diffconfig.config >> .config
    cat $build_dir/OpenWrt-K/config/luci.config >> .config
    cat $build_dir/OpenWrt-K/config/utilities.config >> .config
    cat $build_dir/OpenWrt-K/config/network.config >> .config
    cat $build_dir/OpenWrt-K/config/other.config >> .config
    cat $build_dir/OpenWrt-K/config/kmod.config >> .config
    cat $build_dir/OpenWrt-K/config/image.config >> .config
    make defconfig
}


function clearconfig () {
    cd $build_dir/openwrt || prepare
    cd $build_dir/openwrt
    rm -rf ./tmp
    rm -rf .config
    rm -rf .config.old
    make defconfig
}

function prepare() {
    mkbuilddir
    clone
    load_chenmozhijin-package
    debug
    feeds
    Import_config
    echo '运行环境准备完成/The running environment is ready'
}

function menuconfig() {
    cd $build_dir/openwrt
    make menuconfig || prepareandmenuconfig
}

function prepareandmenuconfig() {
    cd $build_dir/..
    prepare
    make menuconfig
}


function build () {
    cd $build_dir
    rm -rf $build_dir/buildtmp
    mkdir -p $build_dir/buildtmp || prepareandmenuconfig
    mkdir -p $build_dir/buildtmp
    cp $build_dir/openwrt/.config $build_dir/buildtmp/original.config
    cd $build_dir/openwrt
    ./scripts/diffconfig.sh >> $build_dir/buildtmp/diffconfig.config
    cd $build_dir/buildtmp
    sed -e '/^#/s/ is not set/=n/g' -e '/=n/s/# //g' diffconfig.config > diffconfig1.config
    sed -e '/^[a-zA-Z0-9]/s/.*//' -e '/^# CONFIG\_/s/.*//' original.config > note.config
    #
    #
    diffconfig_row=$(wc -l diffconfig.config | sed 's/ .*//')
    line=1
    echo diffconfig_row=$diffconfig_row
    until [ "$line" -eq $(($diffconfig_row+1)) ]; do
        #echo $line $(sed -n "/$(sed -n "${line}p" diffconfig.config)/=" original.config) $(sed -n "${line}p" diffconfig1.config)
        sed -i "$(sed -n "/$(sed -n "${line}p" diffconfig.config)/=" original.config)c $(sed -n "${line}p" diffconfig1.config)" note.config
        line=$(($line+1))
    done
    sed '/^$/d' note.config > diffconfig2.config
    #
    #
    sed -i ':label;N;s/#\n# Configuration\n#\n# end of Configuration//;b label' diffconfig2.config
    sed -i '/^$/d' diffconfig2.config
    for ((i=1; i<=3; i++)); do
    sed -n '/^# end of/p' diffconfig2.config | sed -e "s/# end of //g" -e "s?/?\\\/?g"  > end.list
    endlist_row=$(wc -l end.list | sed 's/ .*//')
    echo endlist_row=$endlist_row
    line=1
    until [ "$line" -eq $(($endlist_row+1)) ]; do
        #echo $line $(sed -n "${line}p" end.list)
        sed -i ":label;N;s/#\n# $(sed -n "${line}p" end.list)\n#\n# end of $(sed -n "${line}p" end.list)//;b label" diffconfig2.config
        line=$(($line+1))
    done
    sed -i '/^$/d' diffconfig2.config
    done
    #
    #
    if test $(echo "a$(sed -n "/# Target Images$/=" diffconfig2.config)a") != "aa"; then
      sed -n "$(($(sed -n "/# Target Images$/=" diffconfig2.config)-1)),$(sed -n "/# end of Target Images$/=" diffconfig2.config)p" diffconfig2.config > image.config
      sed -i "$(($(sed -n "/# Target Images$/=" diffconfig2.config)-1)),$(sed -n "/# end of Target Images$/=" diffconfig2.config)d" diffconfig2.config
    else
      echo "没有Target Images配置"
      echo "" > image.config
    fi
    if test $(echo "a$(sed -n "/# Kernel modules$/=" diffconfig2.config)a") != "aa"; then
      sed -n "$(($(sed -n "/# Kernel modules$/=" diffconfig2.config)-1)),$(sed -n "/# end of Kernel modules$/=" diffconfig2.config)p" diffconfig2.config > kmod.config
      sed -i "$(($(sed -n "/# Kernel modules$/=" diffconfig2.config)-1)),$(sed -n "/# end of Kernel modules$/=" diffconfig2.config)d" diffconfig2.config
    else
      echo "没有Kernel modules配置"
      echo "" > kmod.config
    fi
    if test $(echo "a$(sed -n "/# LuCI$/=" diffconfig2.config)a") != "aa"; then
      sed -n "$(($(sed -n "/# LuCI$/=" diffconfig2.config)-1)),$(sed -n "/# end of LuCI$/=" diffconfig2.config)p" diffconfig2.config > luci.config
      sed -i "$(($(sed -n "/# LuCI$/=" diffconfig2.config)-1)),$(sed -n "/# end of LuCI$/=" diffconfig2.config)d" diffconfig2.config
    else
      echo "没有LuCI配置"
      echo "" > luci.config
    fi
    if test $(echo "a$(sed -n "/# Network$/=" diffconfig2.config)a") != "aa"; then
      sed -n "$(($(sed -n "/# Network$/=" diffconfig2.config)-1)),$(sed -n "/# end of Network$/=" diffconfig2.config)p" diffconfig2.config > network.config
      sed -i "$(($(sed -n "/# Network$/=" diffconfig2.config)-1)),$(sed -n "/# end of Network$/=" diffconfig2.config)d" diffconfig2.config
    else
      echo "没有Network配置"
      echo "" > network.config
    fi
    if test $(echo "a$(sed -n "/# Utilities$/=" diffconfig2.config)a") != "aa"; then
      sed -n "$(($(sed -n "/# Utilities$/=" diffconfig2.config)-1)),$(sed -n "/# end of Utilities$/=" diffconfig2.config)p" diffconfig2.config > utilities.config
      sed -i "$(($(sed -n "/# Utilities$/=" diffconfig2.config)-1)),$(sed -n "/# end of Utilities$/=" diffconfig2.config)d" diffconfig2.config
    else
      echo "没有Utilities配置"
      echo "" > utilities.config
    fi
    if test $(echo "a$(sed -n "/^CONFIG_TARGET_[a-zA-Z0-9]\{1,15\}=y$/=" diffconfig2.config)a") != "aa"; then
      sed -n "/^CONFIG_TARGET_$(sed -n  "/^CONFIG_TARGET_[a-zA-Z0-9]\{1,15\}=y$/p" diffconfig2.config | sed -e 's/CONFIG_TARGET_//'  -e 's/=y//').*/p" diffconfig2.config > target.config
      sed -i "/^CONFIG_TARGET_$(sed -n  "/^CONFIG_TARGET_[a-zA-Z0-9]\{1,15\}=y$/p" diffconfig2.config | sed -e 's/CONFIG_TARGET_//'  -e 's/=y//').*/d" diffconfig2.config
      if test $(echo "a$(sed -n "/^CONFIG_TARGET_MULTI_PROFILE=y$/=" diffconfig2.config)a") != "aa"; then
        sed -n "/^CONFIG_TARGET_MULTI_PROFILE=y$/p" diffconfig2.config >> target.config
        sed -i "/^CONFIG_TARGET_MULTI_PROFILE=y$/d" diffconfig2.config
        if test $(echo "a$(sed -n "/# Target Devices$/=" diffconfig2.config)a") != "aa"; then
          sed -n "$(($(sed -n "/# Target Devices$/=" diffconfig2.config)-1)),$(sed -n "/# end of Target Devices$/=" diffconfig2.config)p" diffconfig2.config >> target.config
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
    cat diffconfig2.config > other.config
    #
    #
    rm -rf ../../config/*.config
    mkdir -p ../../config
    cp image.config ../../config/image.config
    cp kmod.config ../../config/kmod.config
    cp luci.config ../../config/luci.config
    cp network.config ../../config/network.config
    cp utilities.config ../../config/utilities.config
    cp target.config ../../config/target.config
    cp other.config ../../config/other.config
    cd ../../config
    echo "config构建完成"
    echo "输出目录：$(pwd)"
    echo "如果不需要修改config可执行./config_build.sh clear删除运行环境"
}


function main() {
    case "${action}" in
        prepare)
            prepare
            ;;
        build)
            mkbuilddir
            build
            ;;
        menuconfig)
            mkbuilddir
            menuconfig
            ;;
        importconfig)
            mkbuilddir
            Import_config_notarget
            ;;
        clearconfig)
            mkbuilddir
            clearconfig
            ;;
        clear)
            mkbuilddir
            clearall
            ;;
        help)
            help
            ;;
        --help)
            help
            ;;
        *)
        echo "不支持的参数，请使用 help 或 --help 参数获取帮助"
    esac
}
main
