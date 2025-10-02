#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright (c) 2024-2025 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT

# 设置一个用于临时文件的目录，并在脚本退出时自动删除
trap 'rm -rf "$TMPDIR"' EXIT
TMPDIR=$(mktemp -d) || exit 1

# 定义函数"start"，用于执行整个脚本的主要逻辑
function start() {
     # 调用"install_dependencies"函数以安装所需的依赖项
    install_dependencies
    # 检查是否存在配置文件，如果不存在，则执行输入参数的操作
    if [ ! -e "buildconfig.config" ]; then
        input_parameters
        exitstatus=$?
        if [ $exitstatus -eq 6 ]; then
            exit 0
        fi
    fi
    # 检查拓展软件包配置是否正常
    check_ext_packages_config
    # 无限循环，直到用户选择退出菜单
    while true; do
        # 显示菜单
        menu
        exitstatus=$?
        if [ $exitstatus -ne 6 ]; then
            break
        fi
    done
    echo end
}

# 检测安装依赖函数
function install_dependencies() {
    if ! type which &>/dev/null ; then
        echo "未找到which命令"
        exit 1
    fi
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
            # 检查并安装缺少的依赖包（基于apt包管理器）
            for package_name in build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev rsync unzip zlib1g-dev file wget make; do
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
            # 检查并安装缺少的依赖包（基于yum包管理器）
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
            # 如果不支持自动安装依赖的系统，则提示用户使用ubuntu或手动安装openwrt依赖
            if ! (whiptail --title "确认" --yes-button "我已安装全部依赖" --no-button "退出" --yesno "不支持自动安装依赖的系统，建议使用ubuntu或手动安装openwrt依赖。openwrt所需依赖见\nhttps://openwrt.org/docs/guide-developer/toolchain/install-buildsystem#linux_gnu-linux_distributions" 10 104) then
                exit 0
            fi
            ;;
        esac
    if [ -e "$TMPDIR/install.list" ]; then
        # 用户确认是否安装缺少的依赖包
        if (whiptail --title "选择" --yes-button "安装" --no-button "退出" --yesno "是否安装$(cat $TMPDIR/install.list|sed "s/ /、/g")，它们是此脚本的依赖" 10 60) then
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
    if ! type uniq &>/dev/null ; then
        echo "未找到uniq命令"
        exit 1
    fi
    if ! type sort &>/dev/null ; then
        echo "未找到sort命令"
        exit 1
    fi
}

# 检查GitHub API速率限制的函数
function detect_github_api_rate_limit() {
#使用curl命令获取GitHub API的请求剩余次数，并提取整数部分赋值给变量remaining_requests
remaining_requests=$(curl -s -L -i https://api.github.com/users/octocat) || network_error
remaining=$(echo "$remaining_requests"|sed -n "/^x-ratelimit-remaining:/p"|sed "s/.*: //"| awk '{print int($0)}')
# 如果剩余请求次数少于5次，输出超出API速率限制的提示信息
if [ "$remaining" -lt "5" ]; then
    # 使用curl命令获取GitHub API的重置时间，并将时间戳转换为格式化日期字符串
    reset_time=$(date -d @$(echo "$remaining_requests" |sed -n "/^x-ratelimit-reset:/p"|sed "s/.*: //") +"%Y-%m-%d %H:%M:%S") || network_error
    whiptail --title "错误" --msgbox "超出github的 API 速率限制,请等待到$reset_time" 12 60
    return 6
fi
}

# 输入参数函数
function input_parameters() {
    # 调用detect_github_api_rate_limit函数以检查GitHub API速率限制
    detect_github_api_rate_limit
    exitstatus=$?
    if [ $exitstatus = 6 ]; then
        return 6
    fi
    curl -s -L https://api.github.com/repos/openwrt/openwrt/tags|sed -n  '/^    "name": "/p'|sed -e 's/    "name": "//g' -e 's/",//g'> $TMPDIR/tagbranch.list || network_error
    curl -s -L https://api.github.com/repos/openwrt/openwrt/branches|sed -n  '/^    "name": "/p'|sed -e 's/    "name": "//g' -e 's/",//g'>> $TMPDIR/tagbranch.list || network_error
    # 获取最新的OpenWrt标签（tag）
    latest_tag=$(curl -s -L https://api.github.com/repos/openwrt/openwrt/tags|sed -n  '/^    "name": "/p'|sed -e 's/    "name": "//g' -e 's/",//g'| sed -n '1p')
    # 提示用户输入OpenWrt的branch或tag，并将用户输入的值保存到OPENWRT_TAG_BRANCH变量
    inputbox="输入你希望该配置编译的OpenWrt branch或tag，例如v23.05.0-rc1或master"
    OPENWRT_TAG_BRANCH=$(whiptail --title "输入 tag/branch" --inputbox "$inputbox" 10 60 $latest_tag 3>&1 1>&2 2>&3)
    exitstatus=$?
    # 如果用户选择退出，则输出提示信息并退出函数
    if [ $exitstatus != 0 ]; then
        echo "你选择了退出"
        return 6
    fi
    # 检查用户输入的OpenWrt branch或tag是否存在，如果不存在则要求重新输入
    while [ "$(grep -c "^${OPENWRT_TAG_BRANCH}$" $TMPDIR/tagbranch.list)" -eq '0' ]; do
        whiptail --title "错误" --msgbox "输入的OpenWrt branch或tag不存在,选择ok重新输入" 10 60
        OPENWRT_TAG_BRANCH=$(whiptail --title "输入 tag/branch" --inputbox "$inputbox" 10 60 $latest_tag 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            echo "你选择了退出"
            return 6
        fi
    done
    # 提示用户输入OpenWrt-K存储库地址，并保存到OpenWrt_K_url变量
    while true; do
        inputbox="输入OpenWrt-K存储库地址,本工具导入该存储库中的openwrt与OpenWrt-K拓展配置"
        OpenWrt_K_url="$(whiptail --title "输入存储库地址" --inputbox "$inputbox" 10 80 https://github.com/chenmozhijin/OpenWrt-K 3>&1 1>&2 2>&3)"
        exitstatus=$?
        OpenWrt_K_url=$(echo $OpenWrt_K_url|sed  -e 's/^[ \t]*//g' -e's/[ \t]*$//g')
        if [ $exitstatus != 0 ]; then
            echo "你选择了退出"
            return 6
        elif [ -z "$OpenWrt_K_url" ]; then
            whiptail --title "错误" --msgbox "OpenWrt-K存储库不能为空" 10 60
        elif [ "$(echo "$OpenWrt_K_url"|grep -c "[!$^*+\`~\'\"\(\) ]")" -ne '0' ];then
            whiptail --title "错误" --msgbox "OpenWrt-K存储库中有非法字符" 10 60
        elif [ "$(echo "$OpenWrt_K_url"|grep -c "^http[s]\{0,1\}://")" -eq '0' ]  || [ "$(echo "$OpenWrt_K_url"|grep -c ".")" -eq '0' ] ;then
            whiptail --title "错误" --msgbox "OpenWrt-K存储库链接不正常" 10 60
        else
            error_msg=$(git ls-remote --exit-code "$OpenWrt_K_url" 2>&1)
            if [ $? -ne 0 ]; then
                whiptail --title "错误" --msgbox "无效的OpenWrt-K存储库链接，错误信息：\n$error_msg" 10 60
            else
                NEW_EXT_PKG_REPOSITORIE=$(echo "$OpenWrt_K_url"|sed "s/\.git$//g" )
                break
            fi
        fi
    done
    OpenWrt_K_repo=$(echo $OpenWrt_K_url|sed -e "s/https:\/\/github.com\///" -e "s/\/$//" )
    # 提示用户输入OpenWrt-K分支
    while true; do
            OpenWrt_K_branch=$(whiptail --title "输入分支" --inputbox "输入OpenWrt-K存储库分支,本工具导入该存储库分支中的openwrt与OpenWrt-K拓展配置" 10 80 $(curl -s -L --retry 3 https://api.github.com/repos/$OpenWrt_K_repo|grep "\"default_branch\": \""|grep "\","| sed -e "s/  \"default_branch\": \"//g" -e "s/\",//g" ) 3>&1 1>&2 2>&3)
            exitstatus=$?
        if [ $exitstatus != 0 ]; then
            echo "你选择了退出"
            return 6
        elif [ "$(echo "$OpenWrt_K_branch"|grep -c "[!@#$%^&:*=+\`~\'\"\(\)/ ]")" -ne '0' ];then
            whiptail --title "错误" --msgbox "此OpenWrt-K分支中有非法字符" 10 60
        elif [ -z "$OpenWrt_K_branch" ]; then
            whiptail --title "错误" --msgbox "OpenWrt-K存储库分支不能为空" 10 60
        else
    # 检查远程仓库是否有该分支
            if git ls-remote --exit-code --heads "$OpenWrt_K_url" "refs/heads/$OpenWrt_K_branch" 2>&1; then
                break
            else
                whiptail --title "错误" --msgbox "这个OpenWrt-K存储库地址不含有分支 $OpenWrt_K_branch。" 12 70
            fi
        fi
    done
    # 提示用户输入OpenWrt-K配置名
    while true; do
        OpenWrt_K_config="$(whiptail --title "输入配置名" --inputbox "输入要导入的配置名（就是仓库config文件夹下的文件夹名,如：x86_64）,本工具导入该配置中的openwrt与OpenWrt-K拓展配置" 10 80 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            echo "你选择了退出"
            return 6
        elif [ "$(echo "$OpenWrt_K_config"|grep -c "[!@#$%^&:*=+\`~\'\"\(\)/ ]")" -ne '0' ];then
            whiptail --title "错误" --msgbox "配置名中有非法字符，如果配置名包含空格请先删除。" 10 60
        elif [ -z "$OpenWrt_K_config" ]; then
            whiptail --title "错误" --msgbox "配置名为空，请输入配置名" 10 60
        else
            response=$(curl -s -L --retry 3 --connect-timeout 20 "https://api.github.com/repos/$OpenWrt_K_repo/contents/config?ref=$OpenWrt_K_branch")
            if [ "$(echo "$response"|grep -c "^  \"message\": \"Not Found\"," )" -eq '1' ];then
                whiptail --title "错误" --msgbox "未在你提供的OpenWrt-K存储库地址找到config文件夹，响应：\n$response\n点击ok退出" 14 70
                return 6
            elif echo "$response" | grep -q "\"name\": \"$OpenWrt_K_config\""; then
                break
            else
                whiptail --title "错误" --msgbox "这个OpenWrt-K存储库不含有名为 $OpenWrt_K_config 的配置\n请检测你的配置是否存在并关注你提供OpenWrt-K存储库版本" 12 70
            fi
        fi
    done
    if [ -e buildconfig.config ]; then
        if [ "$(grep -c "^build_dir=" buildconfig.config)" -eq '1' ];then
            build_dir=$(grep "^build_dir=" buildconfig.config|sed -e "s/build_dir=//")
        fi
        if [ "$(grep -c "^kmod_compile_exclude_list=" buildconfig.config)" -eq '1' ];then
            kmod_compile_exclude_list=$(grep "^kmod_compile_exclude_list=" buildconfig.config|sed -e "s/kmod_compile_exclude_list=//")
        fi

    fi
    [[  -e $TMPDIR/openwrtext.config ]] && rm -rf $TMPDIR/openwrtext.config
    DOWNLOAD_URL=https://raw.githubusercontent.com/$OpenWrt_K_repo/$OpenWrt_K_branch/config/$OpenWrt_K_config/OpenWrt-K/openwrtext.config
    curl -o $TMPDIR/openwrtext.config -s -L --retry 3 --connect-timeout 20  $DOWNLOAD_URL
    exitstatus=$?
    if [ "$exitstatus" -ne "0" ];then
        whiptail --title "错误" --msgbox "OpenWrt-K拓展配置下载失败，下载链接：\n$DOWNLOAD_URL,curl返回值：$?" 10 110
        return 6
    elif [ "$(cat $TMPDIR/openwrtext.config)" = "404: Not Found" ];then
        whiptail --title "错误" --msgbox "OpenWrt-K拓展配置下载错误 “404: Not Found” ，下载链接：\n$DOWNLOAD_URL" 10 110
        return 6
    fi
    if [ "$(grep -c "^ipaddr=" $TMPDIR/openwrtext.config)" -eq '1' ];then
        ipaddr=$(grep "^ipaddr=" $TMPDIR/openwrtext.config|sed -e "s/ipaddr=//")
    else
        ipaddr="192.168.1.1"
    fi
    if [ "$(grep -c "^timezone=" $TMPDIR/openwrtext.config)" -eq '1' ];then
        timezone=$(grep "^timezone=" $TMPDIR/openwrtext.config|sed -e "s/timezone=//")
    else
        timezone="CST-8"
    fi
    if [ "$(grep -c "^zonename=" $TMPDIR/openwrtext.config)" -eq '1' ];then
        zonename=$(grep "^zonename=" $TMPDIR/openwrtext.config|sed -e "s/zonename=//")
    else
        zonename="Asia/Shanghai"
    fi
    if [ "$(grep -c "^golang_version=" $TMPDIR/openwrtext.config)" -eq '1' ];then
        golang_version=$(grep "^golang_version=" $TMPDIR/openwrtext.config|sed -e "s/golang_version=//")
    else
        golang_version="22.x"
    fi
    DOWNLOAD_URL=https://raw.githubusercontent.com/$OpenWrt_K_repo/$OpenWrt_K_branch/config/$OpenWrt_K_config/OpenWrt-K/compile.config
    curl -o $TMPDIR/compile.config -s -L --retry 3 --connect-timeout 20  $DOWNLOAD_URL
    exitstatus=$?
    if [ "$exitstatus" -ne "0" ];then
        whiptail --title "错误" --msgbox "OpenWrt-K拓展配置下载失败，下载链接：\n$DOWNLOAD_URL,curl返回值：$?" 10 60
        return 6
    elif [ "$(cat $TMPDIR/compile.config)" = "404: Not Found" ];then
        whiptail --title "错误" --msgbox "OpenWrt-K拓展编译配置下载错误 “404: Not Found” ，下载链接：\n$DOWNLOAD_URL" 10 60
        return 6
    fi
    if [ "$(grep -c "^kmod_compile_exclude_list=" $TMPDIR/compile.config)" -eq '1' ];then
        kmod_compile_exclude_list=$(grep "^kmod_compile_exclude_list=" $TMPDIR/compile.config|sed -e "s/kmod_compile_exclude_list=//")
    else
        kmod_compile_exclude_list="kmod-shortcut-fe-cm,kmod-shortcut-fe,kmod-fast-classifier,kmod-shortcut-fe-drv"
    fi
    if [ "$(grep -c "^use_cache=" $TMPDIR/compile.config)" -eq '1' ];then
        use_cache=$(grep "^use_cache=" $TMPDIR/compile.config|sed -e "s/use_cache=//")
    else
        use_cache="true"
    fi
    whiptail --title "完成" --msgbox "你选择的OpenWrt branch或tag为: $OPENWRT_TAG_BRANCH\n选择的OpenWrt-K存储库地址为: $OpenWrt_K_url\n选择的OpenWrt-K存储库分支为: $OpenWrt_K_branch\n选择的配置为: $OpenWrt_K_config" 10 80
    {
        echo "警告：请勿手动修改本文件"
        echo OPENWRT_TAG_BRANCH="$OPENWRT_TAG_BRANCH"
        echo OpenWrt_K_url="$OpenWrt_K_url"
        echo OpenWrt_K_branch="$OpenWrt_K_branch"
        echo OpenWrt_K_config="$OpenWrt_K_config"
        echo ipaddr="$ipaddr"
        echo timezone="$timezone"
        echo zonename="$zonename"
        echo golang_version="$golang_version"
        echo use_cache="$use_cache"
        echo "kmod_compile_exclude_list=$kmod_compile_exclude_list"
    } > buildconfig.config
    if [ -n "$build_dir" ];then
        echo build_dir="$build_dir" >> buildconfig.config
        rm -rf "$build_dir"/OpenWrt-K
        whiptail --title "提示" --msgbox "请重新准备运行环境" 10 80
    fi
    # 调用config_ext_packages函数进行后续配置
    config_ext_packages
}

# 导入拓展软件包配置函数
function import_ext_packages_config() {
    # 让用户选择导入拓展软件包配置的方式
    OPTION=$(whiptail --title "配置拓展软件包" --menu "选择导入拓展软件包配置的方式，如果你没有拓展软件包配置你将只能构建openwrt官方源码与feeds自带的软件包。你现有的拓展软件包配置会被覆盖。" 15 60 4 \
    "1" "从原OpenWrt-K仓库导入默认拓展软件包配置" \
    "2" "从你指定的OpenWrt-K仓库与配置导入指定的拓展软件包配置"  3>&1 1>&2 2>&3)
    exitstatus=$?
    # 如果用户选择退出，则返回11（作为退出标记），否则继续执行
    if [ $exitstatus -ne 0 ]; then
        return 11
    fi
    if [ $OPTION = 1 ]; then
        DOWNLOAD_URL=https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/config/default-extpackages.config
    elif [ $OPTION = 2 ]; then
        # 从配置文件buildconfig.config中提取OpenWrt-K仓库的URL
        OpenWrt_K_url=$(grep "^OpenWrt_K_url=" buildconfig.config|sed  "s/OpenWrt_K_url=//")
        OpenWrt_K_repo=$(echo $OpenWrt_K_url|sed -e "s/https:\/\/github.com\///" -e "s/\/$//" )
        OpenWrt_K_config=$(grep "^OpenWrt_K_config" buildconfig.config|sed  "s/OpenWrt_K_config=//")
        # 获取OpenWrt-K仓库的分支
        branch=$(grep "^OpenWrt_K_branch=" buildconfig.config|sed  "s/OpenWrt_K_branch=//")
        [[ -z "$branch" ]] && echo "错误获取分支失败" && exit 1
        DOWNLOAD_URL=https://raw.githubusercontent.com/$OpenWrt_K_repo/$branch/config/$OpenWrt_K_config/OpenWrt-K/extpackages.config
    else
        echo "错误的选项"
        exit 1
    fi
    # 删除临时目录下的拓展软件包配置文件（如果存在），并下载新的配置文件
    [[  -e $TMPDIR/config_ext_packages/extpackages.config ]] && rm -rf $TMPDIR/config_ext_packages/extpackages.config
    mkdir -p $TMPDIR/config_ext_packages/
    curl -o $TMPDIR/config_ext_packages/extpackages.config -s -L --retry 3 --connect-timeout 20 $DOWNLOAD_URL
    exitstatus=$?
    if [ "$exitstatus" -ne "0" ];then
        echo "拓展软件包配置下载失败，下载链接：$DOWNLOAD_URL,curl返回值：$?"
        exit 1
    elif [ "$(cat $TMPDIR/config_ext_packages/extpackages.config)" = "404: Not Found" ];then
        echo "拓展软件包配置下载错误 “404: Not Found” ，下载链接：$DOWNLOAD_URL"
        exit 1
    elif [ "$(grep -c "^EXT_PACKAGES" $TMPDIR/config_ext_packages/extpackages.config)" -eq '0' ];then
        echo "拓展软件包配置下载未知错误，下载的文件中未检测到配置文件 ，下载链接：$DOWNLOAD_URL"
        exit 1
    fi
    sed -i "/^EXT_PACKAGES/d" buildconfig.config || exit 1
    cat $TMPDIR/config_ext_packages/extpackages.config >> buildconfig.config
    [[  -e $TMPDIR/config_ext_packages/extpackages.config ]] && rm -rf $TMPDIR/config_ext_packages/extpackages.config
}

# 检查拓展软件包配置函数
function check_ext_packages_config() {
    if [ "$(grep -c "^EXT_PACKAGES" buildconfig.config)" -eq '0' ];then
    # 如果buildconfig.config中不存在拓展软件包配置，调用import_ext_packages_config函数进行导入
        import_ext_packages_config
        if [ "$?" -eq '11' ];then
            echo "你选择了退出"
            exit 0
        fi
    fi
    # 检查拓展软件包配置是否正确
    NUMBER_OF_PKGS=$(grep -c "^EXT_PACKAGES_NAME\[" buildconfig.config)
    if [ "$(grep -c "^EXT_PACKAGES_NAME\[$NUMBER_OF_PKGS\]" buildconfig.config)" -eq "0" ];then
        # 如果最后一个配置不存在，则输出错误信息，并调用import_ext_packages_config函数重新导入配置
        whiptail --title "错误" --msgbox "检测到拓展软件包配置有错误，点击ok重新导入（你现有的拓展软件包配置会被覆盖）" 10 60
        sed -i "/^EXT_PACKAGES/d" buildconfig.config || exit 1
        import_ext_packages_config
        if [ "$?" -eq '11' ];then
            echo "你选择了退出"
            exit 0
        fi
    elif [ "$(grep -c "^EXT_PACKAGES_NAME\[$(( $NUMBER_OF_PKGS+1 ))\]" buildconfig.config)" -ne "0" ];then
        # 如果配置中有多余的拓展软件包配置，输出错误信息，并调用import_ext_packages_config函数重新导入配置
        whiptail --title "错误" --msgbox "检测到拓展软件包配置有错误，点击ok重新导入（你现有的拓展软件包配置会被覆盖）" 10 60
        sed -i "/^EXT_PACKAGES/d" buildconfig.config || exit 1
        import_ext_packages_config
        if [ "$?" -eq '11' ];then
            echo "你选择了退出"
            exit 0
        fi
    fi
}

# 配置拓展软件包函数
function config_ext_packages() {
    # 检查拓展软件包配置是否正确
    check_ext_packages_config
    while true; do
        # 调用config_ext_packages_mainmenu函数显示拓展软件包的主菜单
        config_ext_packages_mainmenu
        exitstatus=$?
        if [ $exitstatus -ne 6 ]; then
            break
        fi
    done
}

# 配置拓展软件包的主菜单函数
function config_ext_packages_mainmenu() {
    # 获取拓展软件包配置的数量
    NUMBER_OF_PKGS=$(grep -c "^EXT_PACKAGES_NAME\[" buildconfig.config)
    mkdir -p $TMPDIR/config_ext_packages || exit 1
    rm -rf $TMPDIR/config_ext_packages/menu $TMPDIR/config_ext_packages/submenu
    n=1
    while [ "$n" -le $NUMBER_OF_PKGS ]; do
    # 将拓展软件包的名称和序号添加到临时目录下的菜单文件中
        echo "$n $(grep "^EXT_PACKAGES_NAME\[$n\]" buildconfig.config| sed -e "s/.*=\"//g" -e "s/\"//g")" >> $TMPDIR/config_ext_packages/menu
        n=$(( n+1 ))
    done
    echo "$n 添加一个拓展软件包 " >> $TMPDIR/config_ext_packages/menu
    n=$(( n+1 ))
    echo "$n 重新导入拓展软件包配置 " >> $TMPDIR/config_ext_packages/menu
    # 使用whiptail显示菜单，并根据用户选择执行相应操作
    OPTION=$(whiptail --title "OpenWrt-k配置构建工具-配置拓展软件包菜单" --menu "选择你要修改的配置拓展软件包或选择。请不要重复添加拓展软件包，也不要忘记添加依赖或删除其他包的依赖。如果你已经准备完运行环境请重新载入拓展软件包。选择Cancel返回主菜单。" 25 70 15 $(cat $TMPDIR/config_ext_packages/menu) 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ $OPTION = "$(( $NUMBER_OF_PKGS+1 ))" ]; then  #添加一个拓展软件包
            while true; do
                # 提示用户输入新的拓展软件包名称
                NEW_EXT_PKG_NAME=$(whiptail --title "输入拓展软件包名" --inputbox "此包名将用于创建包存放文件夹，请勿输入空格斜杠或与其他软件包重名" 10 60 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ -z "$NEW_EXT_PKG_NAME" ]; then
                    whiptail --title "错误" --msgbox "拓展软件包名不能为空" 10 60
                elif [ "$(echo "$NEW_EXT_PKG_NAME"|grep -c "[!@#$%^&:*=+\`~\'\"\(\)/ ]")" -ne '0' ];then
                    whiptail --title "错误" --msgbox "拓展软件包名中有非法字符" 10 60
                elif [ "$(sed -n "/^EXT_PACKAGES_NAME/p" buildconfig.config | sed -e "s/.*=\"//g" -e "s/\"//g"|grep -c "^$NEW_EXT_PKG_NAME$")" -ne '0' ];then
                    whiptail --title "错误" --msgbox "此拓展软件包名与其他软件包重名" 10 60
                else
                    break
                fi
            done
            # 提示用户输入新的拓展软件包目录
            while true; do
                NEW_EXT_PKG_PATH=$(whiptail --title "输入拓展软件包在存储库中的目录" --inputbox "输入包与存储库的相对位置，例如一个包在存储库根目录的luci-app-xxx文件夹下则输入luci-app-xxx，如果包就在根目录着可以不输入。" 10 60 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ "$(echo "$NEW_EXT_PKG_PATH"|grep -c "[!@#$%^&:*=+\`~\'\"\(\) ]")" -ne '0' ];then
                    whiptail --title "错误" --msgbox "拓展软件包目录中有非法字符" 10 60
                else
                    break
                fi
            done
            # 提示用户输入新的拓展软件包存储库地址
            while true; do
                NEW_EXT_PKG_REPOSITORIE=$(whiptail --title "输入拓展软件包所在存储库" --inputbox "输入https的存储库地址，无需加“.git”，例如：“https://github.com/chenmozhijin/turboacc”" 10 60 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ -z "$NEW_EXT_PKG_REPOSITORIE" ]; then
                    whiptail --title "错误" --msgbox "拓展软件包所在存储库不能为空" 10 60
                elif [ "$(echo "$NEW_EXT_PKG_REPOSITORIE"|grep -c "[!$^*+\`~\'\"\(\) ]")" -ne '0' ];then
                    whiptail --title "错误" --msgbox "拓展软件包所在存储库中有非法字符" 10 60
                elif [ "$(echo "$NEW_EXT_PKG_REPOSITORIE"|grep -c "^http[s]\{0,1\}://")" -eq '0' ]  || [ "$(echo "$NEW_EXT_PKG_REPOSITORIE"|grep -c ".")" -eq '0' ] ;then
                    whiptail --title "错误" --msgbox "拓展软件包所在存储库链接不正常" 10 60
                else
                    error_msg=$(git ls-remote --exit-code "$NEW_EXT_PKG_REPOSITORIE" 2>&1)
                    if [ $? -ne 0 ]; then
                        whiptail --title "错误" --msgbox "无效的拓展软件包所在存储库链接，错误信息：\n$error_msg" 10 60
                    else
                        NEW_EXT_PKG_REPOSITORIE=$(echo "$NEW_EXT_PKG_REPOSITORIE"|sed "s/\.git$//g" )
                        break
                    fi
                fi
            done
            # 提示用户输入新的拓展软件包分支
            while true; do
                NEW_EXT_PKG_BRANCH=$(whiptail --title "输入拓展软件包所在分支" --inputbox "输入软件包在存储库的分支，一般不输入默认留空使用默认分支即可" 10 60 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ "$(echo "$NEW_EXT_PKG_BRANCH"|grep -c "[!@#$%^&:*=+\`~\'\"\(\)/ ]")" -ne '0' ];then
                    whiptail --title "错误" --msgbox "拓展软件包所在分支中有非法字符" 10 60
                elif [ -z "$NEW_EXT_PKG_BRANCH" ]; then
                    break
                else
                    # 检查远程仓库是否有该分支
                    if git ls-remote --exit-code --heads "$NEW_EXT_PKG_REPOSITORIE" "refs/heads/$NEW_EXT_PKG_BRANCH" 2>&1; then
                        break
                    else
                        whiptail --title "错误" --msgbox "这个拓展软件包存储库地址不含有分支 '$NEW_EXT_PKG_BRANCH'。" 10 60
                    fi
                fi
            done
            # 添加新的拓展软件包配置到buildconfig.config
            NEW_EXT_PKG_NUMBER=$(( $NUMBER_OF_PKGS+1 ))
            sed -i "$(sed -n '/^EXT_PACKAGES/=' buildconfig.config|sed -n '$p')a EXT_PACKAGES_NAME\[$NEW_EXT_PKG_NUMBER\]=\"$NEW_EXT_PKG_NAME\"" buildconfig.config
            sed -i "$(sed -n '/^EXT_PACKAGES/=' buildconfig.config|sed -n '$p')a EXT_PACKAGES_PATH\[$NEW_EXT_PKG_NUMBER\]=\"$NEW_EXT_PKG_PATH\"" buildconfig.config
            sed -i "$(sed -n '/^EXT_PACKAGES/=' buildconfig.config|sed -n '$p')a EXT_PACKAGES_REPOSITORIE\[$NEW_EXT_PKG_NUMBER\]=\"$NEW_EXT_PKG_REPOSITORIE\"" buildconfig.config
            sed -i "$(sed -n '/^EXT_PACKAGES/=' buildconfig.config|sed -n '$p')a EXT_PACKAGES_BRANCH\[$NEW_EXT_PKG_NUMBER\]=\"$NEW_EXT_PKG_BRANCH\"" buildconfig.config
            return 6
        elif [ $OPTION = "$(( $NUMBER_OF_PKGS+2 ))" ]; then  #重新配置软件包数与拓展软件包
            import_ext_packages_config
            if [ "$?" -eq '11' ];then
            echo "你选择了退出"
            return 6
            fi
        elif [ $OPTION -le "$(( $NUMBER_OF_PKGS ))" ]; then  #编辑配置
            while true; do
                # 调用config_ext_packages_submenu函数显示拓展软件包的子菜单
                config_ext_packages_submenu
                exitstatus=$?
                if [ $exitstatus -ne 6 ]; then
                    break
                fi
            done
        fi
        config_ext_packages
    else
        echo "你选择了退出"
        return 0
    fi
}

# 配置拓展软件包的子菜单函数
function config_ext_packages_submenu() {
    # 获取拓展软件包配置的数量
    NUMBER_OF_PKGS=$(grep -c "^EXT_PACKAGES_NAME\[" buildconfig.config)
    # 根据用户选择的序号获取对应拓展软件包的名称、存储库路径、存储库地址和分支
    EXT_PKG_NAME=$(grep "^EXT_PACKAGES_NAME\[$OPTION\]" buildconfig.config| sed -e "s/.*=\"//g" -e "s/\"//g")
    EXT_PKG_PATH=$(grep "^EXT_PACKAGES_PATH\[$OPTION\]" buildconfig.config| sed -e "s/.*=\"//g" -e "s/\"//g")
    EXT_PKG_REPOSITORIE=$(grep "^EXT_PACKAGES_REPOSITORIE\[$OPTION\]" buildconfig.config| sed -e "s/.*=\"//g" -e "s/\"//g")
    EXT_PKG_BRANCH=$(grep "^EXT_PACKAGES_BRANCH\[$OPTION\]" buildconfig.config| sed -e "s/.*=\"//g" -e "s/\"//g")
    # 删除之前的子菜单文件夹，并创建一个新的子菜单文件夹
    rm -rf $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    mkdir -p $TMPDIR/config_ext_packages/submenu/
    # 将拓展软件包的相关信息添加到子菜单文件夹中
    echo "1 包名：$EXT_PKG_NAME" >> $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    if [ -z $EXT_PKG_PATH ]; then
        echo "2 包在存储库中的目录：存储库根目录（空）" >> $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    else
        echo "2 包在存储库中的目录：$EXT_PKG_PATH" >> $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    fi
    echo "3 包所在存储库：$EXT_PKG_REPOSITORIE" >> $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    if [ -z $EXT_PKG_BRANCH ]; then
        echo "4 包所在分支：默认分支（空）" >> $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    else
        echo "4 包所在分支：$EXT_PKG_BRANCH" >> $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    fi
    echo "5 删除此拓展包" >> $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    # 使用whiptail显示子菜单，并根据用户选择执行相应操作
    SUBOPTION=$(whiptail --title "编辑$EXT_PKG_NAME" --menu "选择你要修改项目或选择Cancel返回" 15 90 5 $(cat $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME) 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ "$exitstatus" = "1" ]; then
        echo "你选择了退出"
        return 0
    fi
    case "${SUBOPTION}" in
        1)
            # 编辑拓展软件包名
            while true; do
                NEW_EXT_PKG_NAME=$(whiptail --title "编辑拓展软件包名" --inputbox "此包名将用于创建包存放文件夹，请勿输入空格斜杠或与其他软件包重名" 10 60 $EXT_PKG_NAME 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ -z "$NEW_EXT_PKG_NAME" ]; then
                    whiptail --title "错误" --msgbox "拓展软件包名不能为空" 10 60
                elif [ "$(echo "$NEW_EXT_PKG_NAME"|grep -c "[!@#$%^&:*=+\`~\'\"\(\)/ ]")" -ne '0' ];then
                    whiptail --title "错误" --msgbox "拓展软件包名中有非法字符" 10 60
                elif [ "$(sed -n "/^EXT_PACKAGES_NAME/p" buildconfig.config | sed -e "s/.*=\"//g" -e "s/\"//g"|grep -c "^$NEW_EXT_PKG_NAME$")" -ne '0' ];then
                    whiptail --title "错误" --msgbox "此拓展软件包名与其他软件包重名" 10 60
                else
                    break
                fi
            done
            # 修改拓展软件包名的配置
            sed -i "/^EXT_PACKAGES_NAME\[$OPTION\]/s/=\".*/=\"$NEW_EXT_PKG_NAME\"/g" buildconfig.config
            return 6
            ;;
        2)
             # 编辑拓展软件包在存储库中的目录
            while true; do
                NEW_EXT_PKG_PATH=$(whiptail --title "编辑拓展软件包在存储库中的目录" --inputbox "输入包与存储库的相对位置，例如一个包在存储库根目录的luci-app-xxx文件夹下则输入luci-app-xxx，如果包就在根目录着可以不输入" 10 60 $EXT_PKG_PATH 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ "$(echo "$NEW_EXT_PKG_PATH"|grep -c "[!@#$%^&:*=+\`~\'\"\(\) ]")" -ne '0' ];then
                    whiptail --title "错误" --msgbox "拓展软件包目录中有非法字符" 10 60
                else
                    break
                fi
            done
            # 修改拓展软件包在存储库中的目录的配置
            sed -i "s@EXT_PACKAGES_PATH\[$OPTION\]=\".*@EXT_PACKAGES_PATH\[$OPTION\]=\"$NEW_EXT_PKG_PATH\"@g" buildconfig.config
            return 6
            ;;
        3)
            # 编辑拓展软件包所在存储库
            while true; do
                NEW_EXT_PKG_REPOSITORIE=$(whiptail --title "编辑拓展软件包所在存储库" --inputbox "输入https的存储库地址，无需加“.git”，例如：“https://github.com/chenmozhijin/turboacc”" 10 60 $EXT_PKG_REPOSITORIE 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ -z "$NEW_EXT_PKG_REPOSITORIE" ]; then
                    whiptail --title "错误" --msgbox "拓展软件包所在存储库不能为空" 10 60
                elif [ "$(echo "$NEW_EXT_PKG_REPOSITORIE"|grep -c "[!$^*+\`~\'\"\(\) ]")" -ne '0' ];then
                    whiptail --title "错误" --msgbox "拓展软件包所在存储库中有非法字符" 10 60
                elif [ "$(echo "$NEW_EXT_PKG_REPOSITORIE"|grep -c "^http[s]\{0,1\}://")" -eq '0' ]  || [ "$(echo "$NEW_EXT_PKG_REPOSITORIE"|grep -c ".")" -eq '0' ] ;then
                    whiptail --title "错误" --msgbox "拓展软件包所在存储库链接不正常" 10 60
                else
                    error_msg=$(git ls-remote --exit-code "$NEW_EXT_PKG_REPOSITORIE" 2>&1)
                    if [ $? -ne 0 ]; then
                        whiptail --title "错误" --msgbox "无效的拓展软件包所在存储库链接，错误信息：\n$error_msg" 10 60
                    else
                        NEW_EXT_PKG_REPOSITORIE=$(echo "$NEW_EXT_PKG_REPOSITORIE"|sed "s/\.git$//g" )
                        break
                    fi
                fi
            done
            # 修改拓展软件包所在存储库的配置
            sed -i "s@EXT_PACKAGES_REPOSITORIE\[$OPTION\]=\".*@EXT_PACKAGES_REPOSITORIE\[$OPTION\]=\"$NEW_EXT_PKG_REPOSITORIE\"@g" buildconfig.config
            return 6
            ;;
        4)
            # 编辑拓展软件包所在分支
            while true; do
                NEW_EXT_PKG_BRANCH=$(whiptail --title "编辑拓展软件包所在分支" --inputbox "输入软件包在存储库的分支，一般不输入默认留空使用默认分支即可" 10 60 $EXT_PKG_BRANCH 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ "$(echo "$NEW_EXT_PKG_BRANCH"|grep -c "[!@#$%^&:*=+\`~\'\"\(\)/ ]")" -ne '0' ];then
                    whiptail --title "错误" --msgbox "拓展软件包所在分支中有非法字符" 10 60
                elif [ -z "$NEW_EXT_PKG_BRANCH" ]; then
                    break
                else
                    # 检查远程仓库是否有该分支
                    if git ls-remote --exit-code --heads "$NEW_EXT_PKG_REPOSITORIE" "refs/heads/$NEW_EXT_PKG_BRANCH" 2>&1; then
                        break
                    else
                        whiptail --title "错误" --msgbox "这个拓展软件包存储库地址不含有分支 '$NEW_EXT_PKG_BRANCH'。" 10 60
                    fi
                fi
            done
            # 修改拓展软件包所在分支的配置
            sed -i "/^EXT_PACKAGES_BRANCH\[$OPTION\]/s/=\".*/=\"$NEW_EXT_PKG_BRANCH\"/g" buildconfig.config
            return 6
            ;;
        5)
            # 删除此拓展软件包的配置
            sed -i "/EXT_PACKAGES_[A-Z]\{1,20\}\[$OPTION\]/d" buildconfig.config
            n=$(( $OPTION+1 ))
            while [ "$n" -le $NUMBER_OF_PKGS ]; do
                sed -i "/^EXT_PACKAGES_[A-Z]\{1,20\}\[$n\]/s/\[$n\]=\"/\[$(( $n-1 ))\]=\"/g" buildconfig.config
                n=$(( n+1 ))
            done
            return 0
            ;;
        *)
            echo "错误：未知的选项"
            exit 1
            ;;
    esac
}

# 网络错误提示函数
function network_error() {
    whiptail --title "错误" --msgbox "获取最新OpenWrt branch与tag失败,请检查你的网络环境是否能正常与github通信。" 10 60
    exit 1
}

function menu() {
    # 使用whiptail显示主菜单，让用户选择执行哪个步骤或退出
    OPTION=$(whiptail --title "OpenWrt-k配置构建工具" --menu "选择你要执行的步骤或选择Cancel退出" 20 90 11 \
    "1" "准备运行环境" \
    "2" "打开openwrt配置菜单" \
    "3" "构建配置" \
    "4" "载入OpenWrt-K默认config" \
    "5" "清除所有openwrt配置" \
    "6" "清除运行环境" \
    "7" "重新配置OpenWrt-K存储库地址\分支、OpenWrt branch或tag与拓展软件包" \
    "8" "配置拓展软件包" \
    "9" "重新载入拓展软件包" \
    "10" "OpenWrt-K拓展配置(kmod编译排除列表、IP、时区等)" \
    "11" "关于" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ "$OPTION" = "1" ]; then
            # 准备运行环境选项
            if (whiptail --title "确认" --yesno "这将会下载openwrt以及其插件的源码，请确保你拥有良好的网络环境。选择yes继续no返回菜单。" 10 60) then
                prepare
                exitstatus=$?
                if [ $exitstatus = 4 ]; then
                    cd $build_dir/..
                    whiptail --title "错误" --msgbox "下载失败,请检查你的网络环境是否正常、OpenWrt-K与拓展软件包存储库地址是否正确。如果不是第一次准备请尝试清除运行环境" 10 60
                elif [ $exitstatus = 7 ]; then
                    cd $build_dir/..
                    whiptail --title "错误" --msgbox "git checkot执行失败，请尝试清除运行环境" 10 60
                fi
            fi
            return 6
        elif [ "$OPTION" = "6" ]; then
            # 清除运行环境选项
            if  (whiptail --title "确认" --yesno "这将会删除你未生成的配置与下载的文件。选择yes继续no返回菜单。" 10 60) then
                clearrunningenvironment
            fi
            return 6
        elif [ "$OPTION" = "7" ]; then
            # 重新配置OpenWrt-K存储库地址、OpenWrt branch或tag与拓展软件包选项
            input_parameters
            return 6
        elif [ "$OPTION" = "8" ]; then
            # 配置拓展软件包选项
            config_ext_packages
            return 6
        elif [ "$OPTION" = "10" ]; then
            # openwrt拓展配置选项
            while true; do
                # 调用openwrt_extension_config函数显示拓展配置的菜单
                openwrt_extension_config
                exitstatus=$?
                if [ $exitstatus -ne 6 ]; then
                    break
                fi
            done
            return 6
        elif [ "$OPTION" = "11" ]; then
            # 关于选项
            about
            return 6
        else
            if [ "$(grep -c "^build_dir=" buildconfig.config)" -eq '1' ];then
                if [ -e "$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")/openwrt/feeds/telephony.index" ] && [ -e "$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")/$(echo $OpenWrt_K_url|sed -e "s/https:\/\///" -e "s/\/$//" -e "s/[.\/a-zA-Z0-9]\{1,111\}\///g" -e "s/\ .*//g")" ] ;then
                  case "${OPTION}" in
                    2)
                    # 打开openwrt配置菜单选项
                      menuconfig
                      return 6
                      ;;
                    3)
                    # 构建配置选项
                        if  (whiptail --title "确认" --yesno "这将会覆盖你已生成的配置。选择yes继续no返回菜单。" 10 60) then
                            build
                        fi
                        return 6
                      ;;
                    4)
                    # 载入OpenWrt-K默认config选项
                        if  (whiptail --title "确认" --yesno "这将会覆盖你的现有配置。选择yes继续no返回菜单。" 10 60) then
                            importopenwrt_kconfig
                        fi
                        return 6
                        ;;
                    5)
                    # 清除所有openwrt配置选项
                        if  (whiptail --title "确认" --yesno "这将会删除你的现有配置。选择yes继续no返回菜单。" 10 60) then
                            clearconfig
                        fi
                        return 6
                        ;;
                    9)
                    # 重新载入拓展软件包选项
                        if (whiptail --title "确认" --yesno "这将会重新下载拓展软件包源码，请确保你拥有良好的网络环境。选择yes继续no返回菜单。" 10 60) then
                            build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
                            import_ext_packages
                            if [ $exitstatus = 4 ]; then
                                whiptail --title "错误" --msgbox "下载失败,请检查你的网络环境是否正常与拓展软件包存储库地址是否正确。" 10 60
                            fi
                        fi
                        return 6
                        ;;
                    *)
                      echo "错误：未知的选项"
                      exit 1
                    esac
                else
                    if [ -e "$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")" ];then
                    sed -i "/^build_dir=/d" buildconfig.config
                    fi
                    whiptail --title "错误" --msgbox "你还没有准备运行环境，选择ok以返回菜单。" 10 60
                    return 6
                fi
            else
                whiptail --title "错误" --msgbox "你还没有准备运行环境，选择ok以返回菜单。" 10 60
                return 6
            fi
        fi
    else
        echo "你选择了退出"
        return 0
        exit 0
    fi
}

# 准备运行环境，克隆OpenWrt和拓展软件包仓库
function prepare() {
    # 创建OpenWrt-K_config_build_dir目录
    mkdir -p OpenWrt-K_config_build_dir
    # 检查是否已存在build_dir配置，若有则设置相应变量，否则创建新的build_dir配置
    if [ "$(grep -c "^build_dir=" buildconfig.config)" -eq '1' ];then
        build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
        openwrt_dir=$build_dir/openwrt
        cd $build_dir
    else
        cd OpenWrt-K_config_build_dir
        build_dir=$(pwd)
        sed -i "\$a\build_dir=$build_dir" $build_dir/../buildconfig.config
        openwrt_dir=$build_dir/openwrt
    fi
    # 获取OpenWrt-K的存储库URL、OpenWrt-K所在目录和选择的OPENWRT分支/标签
    OpenWrt_K_url=$(grep "^OpenWrt_K_url=" $build_dir/../buildconfig.config|sed  "s/OpenWrt_K_url=//")
    OpenWrt_K_dir=$build_dir/$(echo $OpenWrt_K_url|sed -e "s/https:\/\///" -e "s/\/$//" -e "s/[.\/a-zA-Z0-9]\{1,111\}\///g" -e "s/\ .*//g")
    OpenWrt_K_branch=$(grep "^OpenWrt_K_branch=" $build_dir/../buildconfig.config|sed  "s/OpenWrt_K_branch=//")
    OpenWrt_K_config=$(grep "^OpenWrt_K_config" $build_dir/../buildconfig.config|sed  "s/OpenWrt_K_config=//")
    OPENWRT_TAG_BRANCH=$(grep "^OPENWRT_TAG_BRANCH=" $build_dir/../buildconfig.config|sed  "s/OPENWRT_TAG_BRANCH=//")
    # 检查OpenWrt-K目录是否已存在，若存在则执行git pull更新，否则执行git clone克隆
    if [ -d "$OpenWrt_K_dir" ]; then
        git -C $OpenWrt_K_dir pull || return 4
    else
        git clone $OpenWrt_K_url $OpenWrt_K_dir -b $OpenWrt_K_branch || return 4
    fi
    # 检查openwrt目录是否已存在，若存在则执行git pull更新并检查分支/标签，否则执行git clone克隆
    if [ -d "$openwrt_dir" ]; then
        cd $openwrt_dir
        if ! [[ "$OPENWRT_TAG_BRANCH" =~ ^v.* ]]; then
            git checkout $OPENWRT_TAG_BRANCH || return 4
            git -C $openwrt_dir pull || return 4
        else
            if ! [[ "$(git branch |sed -n "/^\* /p"|sed "s/\* //")" =~ ^\(HEAD\ detached\ at\ v.* ]]; then
                git -C $openwrt_dir pull || return 4
                git checkout $OPENWRT_TAG_BRANCH
                exitstatus=$?
                # 若检出标签失败，则删除openwrt目录并重新克隆OpenWrt源码
                if [ $exitstatus -ne 0 ]; then
                    rm -rf $openwrt_dir
                    git clone https://github.com/openwrt/openwrt $openwrt_dir || return 4
                    cd $openwrt_dir
                    git checkout $OPENWRT_TAG_BRANCH || return 7
                fi
            fi
        fi
    else
        git clone https://github.com/openwrt/openwrt $openwrt_dir || return 4
        cd $openwrt_dir
        git checkout $OPENWRT_TAG_BRANCH || return 7
    fi
    #克隆拓展软件包仓库
    inputbox="准备完成，选择ok以返回菜单。"
    import_ext_packages
    exitstatus=$?
    if [ $exitstatus = 4 ]; then
        return 4
    elif [ $exitstatus = 1 ]; then
        inputbox="准备完成。但有软件包依赖错误，请尝试修复，选择ok以返回菜单。"
    fi
    #修复问题
    cd $openwrt_dir
    sed -i 's/^  DEPENDS:= +kmod-crypto-manager +kmod-crypto-pcbc +kmod-crypto-fcrypt$/  DEPENDS:= +kmod-crypto-manager +kmod-crypto-pcbc +kmod-crypto-fcrypt +kmod-udptunnel4 +kmod-udptunnel6/' package/kernel/linux/modules/netsupport.mk
    sed -i 's/^	dnsmasq \\$/	dnsmasq-full \\/g' ./include/target.mk
    sed -i 's/^	b43-fwsquash.py "$(CONFIG_B43_FW_SQUASH_PHYTYPES)" "$(CONFIG_B43_FW_SQUASH_COREREVS)"/	$(TOPDIR)\/tools\/b43-tools\/files\/b43-fwsquash.py "$(CONFIG_B43_FW_SQUASH_PHYTYPES)" "$(CONFIG_B43_FW_SQUASH_COREREVS)"/' ./package/kernel/mac80211/broadcom.mk
    # 删除旧的.config和tmp目录，并将OpenWrt-K中的OpenWrt配置合并到新的.config中
    [[ -d $openwrt_dir ]] && rm -rf .config
    [[ -d $openwrt_dir ]] && rm -rf $openwrt_dir/tmp
    cat $OpenWrt_K_dir/config/$OpenWrt_K_config/{target,luci,utilities,network,other,kmod,image}.config >> .config
    make defconfig
    sed -i 's/256/1024/' ./target/linux/$(sed -n '/CONFIG_TARGET_BOARD/p' .config | sed -e 's/CONFIG_TARGET_BOARD\=\"//' -e 's/\"//')/image/Makefile
    cd $build_dir/..
    # 显示准备完成提示信息	
    whiptail --title "完成" --msgbox "$inputbox" 10 60
    return 0
}

# 导入拓展软件包函数，克隆拓展软件包仓库并进行整理
function import_ext_packages() {
    # 设置变量
    openwrt_dir=$build_dir/openwrt
    [[ -d $build_dir/extpackages ]] && rm -rf $build_dir/extpackages
    [[ -d $TMPDIR/extpackages_prepare ]] && rm -rf $TMPDIR/extpackages_prepare
    EXT_PKGS_PREP_PATH=$TMPDIR/extpackages_prepare
    EXT_PKGS_DL_PATH=$build_dir/extpackages/dl
    EXT_PKGS_PATH=$build_dir/extpackages/extpackages
    EXT_PKGS_CONFIG=$EXT_PKGS_PREP_PATH/extpackages.config
    # 创建必要的目录结构
    mkdir -p $EXT_PKGS_PREP_PATH $EXT_PKGS_PATH $EXT_PKGS_DL_PATH
    sed -n "/^EXT_PACKAGES/p" $build_dir/../buildconfig.config > $EXT_PKGS_CONFIG
    NUMBER_OF_PKGS=$(grep -c "^EXT_PACKAGES_NAME\[" $EXT_PKGS_CONFIG)
    # 提取拓展软件包配置信息并生成拓展软件包仓库URL与分支的配置文件
    n=1
    while [ "$n" -le $NUMBER_OF_PKGS ]; do
        EXT_PKG_REPOSITORIE=$(grep "^EXT_PACKAGES_REPOSITORIE\[$n\]" $EXT_PKGS_CONFIG| sed -e "s/.*=\"//g" -e "s/\"//g")
        EXT_PKG_BRANCH=$(grep "^EXT_PACKAGES_BRANCH\[$n\]" $EXT_PKGS_CONFIG| sed -e "s/.*=\"//g" -e "s/\"//g")
        echo "REPOSITORIE=$EXT_PKG_REPOSITORIE BRANCH=$EXT_PKG_BRANCH" >> $EXT_PKGS_PREP_PATH/extpackagesbr.config
        n=$(( n+1 ))
    done
    # 整理拓展软件包仓库克隆配置，去重并生成参数
    sort $EXT_PKGS_PREP_PATH/extpackagesbr.config|uniq > $EXT_PKGS_PREP_PATH/clone.config
    sed -i -e "s/BRANCH=$//g" $EXT_PKGS_PREP_PATH/clone.config
    sed -i -e "s/BRANCH=/--branch /g" $EXT_PKGS_PREP_PATH/clone.config
    NUMBER_OF_CLONES=$(grep -c "REPOSITORIE=" $EXT_PKGS_PREP_PATH/clone.config)
    sed -i "s/^REPOSITORIE=//g" $EXT_PKGS_PREP_PATH/clone.config
    # 克隆拓展软件包仓库并整理
    echo "开始克隆拓展软件包仓库"
    n=1
    while [ "$n" -le $NUMBER_OF_CLONES ]; do
        mkdir -p $EXT_PKGS_DL_PATH/TMP
        COLNE_ARGUMENT=$(sed -n "${n}p" $EXT_PKGS_PREP_PATH/clone.config)
        git clone --depth=1 --single-branch $COLNE_ARGUMENT $EXT_PKGS_DL_PATH/TMP  || return 4
        cd $EXT_PKGS_DL_PATH/TMP
        if [ "$(echo "$COLNE_ARGUMENT" | grep -c " --branch ")" -ne '0' ];then
            BRANCH=$(git rev-parse --abbrev-ref HEAD)
        else
            BRANCH="default_branch"
        fi
        REPO_PATH="$BRANCH""/""$(echo "$COLNE_ARGUMENT" | sed -e "s/ --branch.*//g" -e "s@.*://@@g" -e "s/^[a-zA-Z.]\{1,111\}\///" -e "s/\/$//g")"
        cd $build_dir/..
        mkdir -p $EXT_PKGS_DL_PATH/$REPO_PATH
        cp -RT $EXT_PKGS_DL_PATH/TMP/ $EXT_PKGS_DL_PATH/$REPO_PATH
        rm -rf $EXT_PKGS_DL_PATH/TMP/
        n=$(( n+1 ))
    done
    # 整理拓展软件包并修复包的一些问题
    echo "开始整理拓展软件包"
    n=1
    while [ "$n" -le $NUMBER_OF_PKGS ]; do
        NUMBER_OF_PKGS=$(grep -c "^EXT_PACKAGES_NAME\[" $EXT_PKGS_CONFIG)
        EXT_PKG_NAME=$(grep "^EXT_PACKAGES_NAME\[$n\]" $EXT_PKGS_CONFIG| sed -e "s/.*=\"//g" -e "s/\"//g")
        EXT_PKG_PATH=$(grep "^EXT_PACKAGES_PATH\[$n\]" $EXT_PKGS_CONFIG| sed -e "s/.*=\"//g" -e "s/\"//g")
        EXT_PKG_REPOSITORIE=$(grep "^EXT_PACKAGES_REPOSITORIE\[$n\]" $EXT_PKGS_CONFIG| sed -e "s/.*=\"//g" -e "s/\"//g")
        EXT_PKG_BRANCH=$(grep "^EXT_PACKAGES_BRANCH\[$n\]" $EXT_PKGS_CONFIG| sed -e "s/.*=\"//g" -e "s/\"//g")
        EXT_PKG_REPO_PATH=$(echo "$EXT_PKG_REPOSITORIE" | sed -e 's/[[:space:]]*$//' -e "s/\.git$//g" -e "s/ .*//g" -e "s@.*://@@g" -e "s/^[a-zA-Z.]\{1,111\}\///" -e "s/\/$//g")
        if [ -z "$EXT_PKG_BRANCH" ];then
            EXT_PKG_BRANCH="default_branch"
        fi
        mkdir -p $EXT_PKGS_PATH/$EXT_PKG_NAME
        cp -RT $EXT_PKGS_DL_PATH/$EXT_PKG_BRANCH/$EXT_PKG_REPO_PATH/$EXT_PKG_PATH $EXT_PKGS_PATH/$EXT_PKG_NAME
        n=$(( n+1 ))
    done
    cd $EXT_PKGS_PATH
    # 修复包的一些问题
    sed -i 's/include ..\/..\/luci.mk/include $(TOPDIR)\/feeds\/luci\/luci.mk/' $(find ./ -type f -name "Makefile")
    find . -name 'po' -type d > $EXT_PKGS_PREP_PATH/podir.list
    total_rows=$(sed -n '$=' $EXT_PKGS_PREP_PATH/podir.list) #行数-文件夹个数
    n=1
    while [ "$n" -le $total_rows ]; do
        DIR=$(sed -n "${n}p" $EXT_PKGS_PREP_PATH/podir.list)
        if [ -h $DIR/zh_Hans ]; then
            echo "$DIR/zh_Hans 符号链接以存在无需修复"
        elif [ -d $DIR/zh_Hans ]; then
            echo "$DIR/zh_Hans 目录已存在无需修复"
        elif [ -e $DIR/zh_Hans ]; then
            echo "$DIR/zh_Hans 存在非符号链接文件删除后重新创建"
            rm -rf $DIR/zh_Hans||exit 1
            ln -s zh-cn $DIR/zh_Hans||exit 1
        elif [ ! -d $DIR/zh-cn ]; then
            echo "$DIR/zh-cn 原汉化文件夹不存在，这可能是该luci插件原生为中文或不支持中文"
        else
            echo "$DIR/zh_Hans 符号链接不存在创建符号链接"
            ln -s zh-cn $DIR/zh_Hans||exit 1
        fi
        n=$(( n+1 ))
    done
    # 复制拓展软件包至OpenWrt目录，并更新和安装feeds
    [[ -d $openwrt_dir ]] && rm -rf $openwrt_dir/package/extpackages
    mkdir -p $openwrt_dir/package/extpackages
    cp -RT $EXT_PKGS_PATH $openwrt_dir/package/extpackages
    rm -rf $EXT_PKGS_PREP_PATH $build_dir/extpackages
    cd $openwrt_dir
    ./scripts/feeds update -a  || return 4
    ./scripts/feeds install -a
    check_packagedeps
    exitstatus=$?
    if [ $exitstatus = 1 ]; then
        cd $build_dir/..
        return 1
    else
        cd $build_dir/..
        return 0
    fi
    
}

# 检查软件包依赖函数
function check_packagedeps() {
    # 设置变量
    openwrt_dir=$build_dir/openwrt
    PACKAGEDEPWARNING=$TMPDIR/packagedepwarning.log
    # 进入OpenWrt目录并清理之前的依赖错误记录
    cd $openwrt_dir
    rm -rf $PACKAGEDEPWARNING
    # 使用` gmake -s prepare-tmpinfo`检查软件包依赖并将错误信息保存至`$PACKAGEDEPWARNING`
    gmake -s prepare-tmpinfo
    ./scripts/package-metadata.pl mk tmp/.packageinfo > tmp/.packagedeps 2>$PACKAGEDEPWARNING || { rm -f tmp/.packagedeps; false; } 
    # 检查是否有软件包依赖问题，如果有，使用whiptail显示错误提示信息，并返回1
    if [ -n "$(cat $PACKAGEDEPWARNING)" ]; then
        #有错误
        echo "发现错误"
        whiptail --title "错误" --msgbox "检查到软件包依赖问题：\n$(cat $PACKAGEDEPWARNING)\n这大概率与错误的拓展软件包配置有关，请尝试重新配置拓展软件包" 30 110
        return 1
    else
        return 0
    fi
}

function menuconfig() {
    # 获取build_dir目录路径
    build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
    # 提示用户是否要修改OpenWrt的TARGET配置
    if (whiptail --title "选择" --yesno "你是否要修改openwrt的TARGET配置？" 10 60) then
        targetconfig
    else
        echo "You chose No. Exit status was $?."
    fi
    # 进入OpenWrt目录并执行make menuconfig
    cd $build_dir/openwrt
    make menuconfig
    cd $build_dir/..
}

# 修改OpenWrt的TARGET配置
function targetconfig() {
    # 获取build_dir目录路径和openwrt_dir目录路径
    build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
    openwrt_dir=$build_dir/openwrt
    # 创建临时目录
    [[ -d $TMPDIR/targetconfig ]] && rm -rf $TMPDIR/targetconfig
    mkdir -p $TMPDIR/targetconfig
    targetconfigpath=$TMPDIR/targetconfig/
    targetdiffconfig=$targetconfigpath/diff.config
    notargetdiffconfig=$targetconfigpath/notargetdiff.config
    # 进入OpenWrt目录并生成TARGET配置差异文件
    cd $openwrt_dir
    ./scripts/diffconfig.sh > $targetdiffconfig
    TARGET=$(sed -n  "/^CONFIG_TARGET_[a-zA-Z0-9]\{1,15\}=y$/p" $targetdiffconfig | sed -e 's/CONFIG_TARGET_//'  -e 's/=y//')
    # 进行一些差异文件的处理，包括删除旧的TARGET配置，提示用户修改新的TARGET配置，再更新配置文件
    sed "/^CONFIG_TARGET_${TARGET}.*/d" $targetdiffconfig > $notargetdiffconfig
    sed -i "/^CONFIG_TARGET_MULTI_PROFILE=y$/d" $notargetdiffconfig
    sed -i "/^CONFIG_TARGET_DEVICE_${TARGET}.*/d" $notargetdiffconfig
    sed -i "/^# CONFIG_TARGET_DEVICE_${TARGET}.*/d" $notargetdiffconfig
    sed -i "/^CONFIG_TARGET_DEVICE_PACKAGES_${TARGET}.*/d" $notargetdiffconfig
    sed -i "/^CONFIG_TARGET_PER_DEVICE_ROOTFS=y$/d" $notargetdiffconfig
    sed -i "/^CONFIG_TARGET_ALL_PROFILES=y$/d" $notargetdiffconfig
    whiptail --title "提示" --msgbox "点击ok后，请仅修改TARGET配置然后保存退出，请勿修改其他配置或修改保存的目录与文件名" 10 60
    cd $build_dir/openwrt
    make menuconfig
    cat $notargetdiffconfig >> $openwrt_dir/.config
    make defconfig
    sed -i 's/256/1024/' ./target/linux/$(sed -n '/CONFIG_TARGET_BOARD/p' .config | sed -e 's/CONFIG_TARGET_BOARD\=\"//' -e 's/\"//')/image/Makefile
    [[ -d $TMPDIR/targetconfig ]] && rm -rf $TMPDIR/targetconfig
    cd $build_dir/..
}

# 导入OpenWrt-K的配置文件至当前OpenWrt目录
function importopenwrt_kconfig() {
    # 获取build_dir目录路径和openwrt_dir目录路径
    build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
    openwrt_dir=$build_dir/openwrt
    # 获取OpenWrt-K配置文件的URL并生成OpenWrt-K目录路径
    OpenWrt_K_url=$(grep "^OpenWrt_K_url=" $build_dir/../buildconfig.config|sed  "s/OpenWrt_K_url=//")
    OpenWrt_K_dir=$build_dir/$(echo $OpenWrt_K_url|sed -e "s/https:\/\///" -e "s/\/$//" -e "s/[.\/a-zA-Z0-9]\{1,111\}\///g" -e "s/\ .*//g")
    OpenWrt_K_config=$(grep "^OpenWrt_K_config" $build_dir/../buildconfig.config|sed  "s/OpenWrt_K_config=//")
    # 进入OpenWrt目录，并将OpenWrt-K的配置文件合并到当前OpenWrt配置文件
    cd $openwrt_dir
    [[ -d $openwrt_dir ]] && rm -rf .config
    cat $OpenWrt_K_dir/config/$OpenWrt_K_config/{target,luci,utilities,network,other,kmod,image}.config >> .config
    make defconfig
    cd $build_dir/..
}

# 清除OpenWrt目录的配置文件和临时文件
function clearconfig() {
    # 获取build_dir目录路径和openwrt_dir目录路径
    build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
    openwrt_dir=$build_dir/openwrt
    # 删除OpenWrt目录的配置文件和临时文件
    [[ -d $openwrt_dir ]] && rm -rf $openwrt_dir/tmp
    [[ -d $openwrt_dir ]] && rm -rf $openwrt_dir/.config
    [[ -d $openwrt_dir ]] && rm -rf $openwrt_dir/.config.old
    # 重新生成默认配置
    cd $openwrt_dir
    make defconfig
    cd $build_dir/..
}

# 清除运行环境的配置
function clearrunningenvironment() {
    # 获取build_dir目录路径，并删除整个build_dir目录
    build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
    cd $build_dir/..
    rm -rf $build_dir
    # 在buildconfig.config中删除build_dir配置
    sed -i  "/^build_dir=/d" buildconfig.config
}

openwrt_extension_config() {
    # 使用whiptail显示菜单，让用户选择修改哪个配置或退出
    ipaddr=$(grep "^ipaddr=" buildconfig.config|sed -e "s/ipaddr=//")
    timezone=$(grep "^timezone=" buildconfig.config|sed -e "s/timezone=//")
    zonename=$(grep "^zonename=" buildconfig.config|sed -e "s/zonename=//")
    golang_version=$(grep "^golang_version=" buildconfig.config|sed -e "s/golang_version=//")
    use_cache=$(grep "^use_cache=" buildconfig.config|sed -e "s/use_cache=//")
    OPTION=$(whiptail --title "OpenWrt-k配置构建工具-拓展配置" --menu "选择你要修改的内容或选择Cancel退出" 16 80 8 \
    "1" "修改IP地址: $ipaddr" \
    "2" "修改时区：$timezone" \
    "3" "修改时区区域名称: $zonename" \
    "4" "修改内核模块(kmod)编译排除列表" \
    "5" "修改golang版本: $golang_version" \
    "6" "使用缓存: $use_cache" \
    "7" "恢复默认拓展配置"  3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ "$exitstatus" = "1" ]; then
        echo "你选择了退出"
        return 0
    fi
    case "${OPTION}" in
        1)
            # 编辑ip地址
            while true; do
                NEW_IPADDR=$(whiptail --title "修改IP地址" --inputbox "默认IP：192，168.1.1容易与光猫路由器冲突，这可能导致无法访问openwrt或互联网，你可以在这里修改openwrt默认ip" 10 60 $ipaddr 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ -z "$NEW_IPADDR" ]; then
                    whiptail --title "错误" --msgbox "ip地址不能为空" 10 60
                elif [ "$(echo "$NEW_IPADDR"|grep -c "[A-Za-z!@#$%^&:*=+\`~\'\"\(\)/ ]")" -ne '0' ];then
                    whiptail --title "错误" --msgbox "ip地址中有非法字符" 10 60
                else
                    break
                fi
            done
            # 修改ip地址的配置
            sed -i "/^ipaddr/s/=.*/=$NEW_IPADDR/g" buildconfig.config
            return 6
            ;;
        2)
             # 修改时区
            while true; do
                NEW_TIMEZONE=$(whiptail --title "修改时区" --inputbox "默认为东八区(CST-8),中国地区无需修改" 10 60 $timezone 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ -z "$NEW_TIMEZONE" ]; then
                    whiptail --title "错误" --msgbox "时区不能为空" 10 60
                elif [ "$(echo "$NEW_TIMEZONE"|grep -c "[!@#$%^&:*=+\`~\'\"\(\) ]")" -ne '0' ];then
                    whiptail --title "错误" --msgbox "时区中有非法字符" 10 60
                else
                    break
                fi
            done
            # 修改时区的配置
            sed -i "/^timezone=/s/=.*/=$NEW_TIMEZONE/g" buildconfig.config
            return 6
            ;;
        3)
            # 修改时区区域名称
            while true; do
                NEW_ZONENAME=$(whiptail --title "修改时区区域名称" --inputbox "默认为Asia/Shanghai,中国大陆地区无需修改" 10 60 $zonename 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ -z "$NEW_ZONENAME" ]; then
                    whiptail --title "错误" --msgbox "时区区域不能为空" 10 60
                elif [ "$(echo "$NEW_ZONENAME"|grep -c "[!@#$%^&:*=+\`~'\" ]")" -ne '0' ];then
                    whiptail --title "错误" --msgbox "时区区域中有非法字符" 10 60
                else
                    break
                fi
            done
            # 修改时区区域名称的配置
            sed -i "/^zonename=/s#=.*#=$NEW_ZONENAME#g" buildconfig.config
            return 6
            ;;
        4)
            # 修改内核模块(kmod)编译排除列表
            while true; do
                kmod_compile_exclude_list=$(whiptail --title "修改内核模块(kmod)编译排除列表" --inputbox "修改内核模块包名，不同包名之间用英语逗号分隔，支持通字符.*。" 10 120 $(grep "^kmod_compile_exclude_list=" buildconfig.config|sed  "s/kmod_compile_exclude_list=//") 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ "$(echo "$kmod_compile_exclude_list"|grep -c "[!@#$%^&:=+\`~'\" ]")" -ne '0' ];then
                    whiptail --title "错误" --msgbox "内核模块(kmod)编译排除列表中有非法字符" 10 60
                else
                    break
                fi
            done
            # 修改内核模块(kmod)编译排除列表
            sed -i  "/^kmod_compile_exclude_list=/s/=.*/=$kmod_compile_exclude_list/g" buildconfig.config
            return 6
            ;;
        5)
            # 修改golang版本
            # 从 GitHub API 获取分支信息并提取名称
            branches=$(curl -s -L https://api.github.com/repos/sbwml/packages_lang_golang/branches | sed -n '/^    "name": "/p' | sed -e 's/    "name": "//g' -e 's/",//g')

            # 将分支名称存储到数组中
            branch_array=($branches)

            # 使用 whiptail 创建菜单
            choices=()
            index=1
            for branch in "${branch_array[@]}"; do
                choices+=("$index" "$branch")
                ((index++))
            done

            # 获取用户选择
            choice=$(whiptail --title "选择分支" --menu "请选择一个分支:" 15 60 4 "${choices[@]}" 3>&1 1>&2 2>&3)
            exitstatus=$?
            if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
            fi

            NEW_GOLANG_VERSION="${branch_array[choice-1]}"
            sed -i "/^golang_version=/s#=.*#=$NEW_GOLANG_VERSION#g" buildconfig.config
            return 6
            ;;
        6)
            # 修改使用缓存
            if [ "$use_cache" = "true" ] || [ "$use_cache" = "True" ] || [ "$use_cache" = "TRUE" ];then
                sed -i "/^use_cache=/s#=.*#=false#g" buildconfig.config
                use_cache="false"
            else
                sed -i "/^use_cache=/s#=.*#=true#g" buildconfig.config
                use_cache="true"
            fi
            return 6
            ;;
        7)
            sed -i "/^ipaddr/s/=.*/=192.168.1.1/g" buildconfig.config
            sed -i "/^timezone=/s/=.*/=CST-8/g" buildconfig.config
            sed -i "/^zonename=/s#=.*#=Asia/Shanghai#g" buildconfig.config
            sed -i  "/^kmod_compile_exclude_list=/s/=.*/=kmod-shortcut-fe-cm,kmod-shortcut-fe,kmod-fast-classifier/g" buildconfig.config
            sed -i "/^use_cache=/s/=.*/=true/g" buildconfig.config
            sed -i "/^golang_version=/s/=.*/=22.x/g" buildconfig.config
            return 6
            ;;
        *)
            echo "错误：未知的选项"
            exit 1
            ;;
    esac
}

# 显示关于信息
function about() {
    whiptail --title "关于" --msgbox "\
OpenWrt-k配置构建工具\n\
\n\
版本：v1.2\n\
Copyright © 2023 沉默の金\n\
\n\
本软件基于MIT开源协议发布。你可以在MIT协议的允许范围内自由使用、修改和分发本软件。\n\
\n\
MIT开源协议的完整文本可以在以下位置找到：https://github.com/chenmozhijin/OpenWrt-K/blob/main/LICENSE\n\
更多关于本软件的信息和源代码可以在我的代码仓库找到：https://github.com/chenmozhijin/OpenWrt-K" 20 110
}

# 构建OpenWrt-K配置文件
function build () {
    #准备工作
    build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
    openwrt_dir=$build_dir/openwrt
    OpenWrt_K_config=$(grep "^OpenWrt_K_config" $build_dir/../buildconfig.config|sed  "s/OpenWrt_K_config=//")
    # 检查软件包依赖是否满足要求，如果有错误则提示用户修复
    check_packagedeps
    exitstatus=$?
    if [ $exitstatus = 1 ]; then
        whiptail --title "提示" --msgbox "请先修复软件包依赖错误在构建配置" 10 60
        cd $build_dir/..
        return 1
    fi
    # 创建临时目录和输出目录
    [[ -d $TMPDIR/buildconfig ]] && rm -rf $TMPDIR/buildconfig
    [[ -d $TMPDIR/output ]] && rm -rf $TMPDIR/output
    buildconfigdir=$TMPDIR/buildconfig
    outputdir=$TMPDIR/output
    mkdir -p $buildconfigdir
    mkdir -p $outputdir/OpenWrt-K/
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
        echo $line $(sed -n "/$(sed -n "${line}p" diffconfig.config|sed -e 's@"@\\"@g' -e 's@/@\\/@g' )/=" original.config) $(sed -n "${line}p" diffconfig1.config)
        sed -i "$(sed -n "/$(sed -n "${line}p" diffconfig.config|sed -e 's@"@\\"@g' -e 's@/@\\/@g' )/=" original.config)c $(sed -n "${line}p" diffconfig1.config|sed 's@"@\\"@g')" diffconfig2.config
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
      > $outputdir/image.config
    fi
    if [ "$(grep -c "# Kernel modules$" diffconfig2.config)" -ne '0' ];then
      sed -n "$(($(sed -n "/# Kernel modules$/=" diffconfig2.config)-1)),$(sed -n "/# end of Kernel modules$/=" diffconfig2.config)p" diffconfig2.config > $outputdir/kmod.config
      sed -i "$(($(sed -n "/# Kernel modules$/=" diffconfig2.config)-1)),$(sed -n "/# end of Kernel modules$/=" diffconfig2.config)d" diffconfig2.config
    else
      echo "没有Kernel modules配置"
      > $outputdir/kmod.config
    fi
    if [ "$(grep -c "# LuCI$" diffconfig2.config)" -ne '0' ];then
      sed -n "$(($(sed -n "/# LuCI$/=" diffconfig2.config)-1)),$(sed -n "/# end of LuCI$/=" diffconfig2.config)p" diffconfig2.config > $outputdir/luci.config
      sed -i "$(($(sed -n "/# LuCI$/=" diffconfig2.config)-1)),$(sed -n "/# end of LuCI$/=" diffconfig2.config)d" diffconfig2.config
    else
      echo "没有LuCI配置"
      > $outputdir/luci.config
    fi
    if [ "$(grep -c "# Network$" diffconfig2.config)" -ne '0' ];then
      sed -n "$(($(sed -n "/# Network$/=" diffconfig2.config)-1)),$(sed -n "/# end of Network$/=" diffconfig2.config)p" diffconfig2.config > $outputdir/network.config
      sed -i "$(($(sed -n "/# Network$/=" diffconfig2.config)-1)),$(sed -n "/# end of Network$/=" diffconfig2.config)d" diffconfig2.config
    else
      echo "没有Network配置"
      > $outputdir/network.config
    fi
    if [ "$(grep -c "# Utilities$" diffconfig2.config)" -ne '0' ];then
      sed -n "$(($(sed -n "/# Utilities$/=" diffconfig2.config)-1)),$(sed -n "/# end of Utilities$/=" diffconfig2.config)p" diffconfig2.config > $outputdir/utilities.config
      sed -i "$(($(sed -n "/# Utilities$/=" diffconfig2.config)-1)),$(sed -n "/# end of Utilities$/=" diffconfig2.config)d" diffconfig2.config
    else
      echo "没有Utilities配置"
      > $outputdir/utilities.config
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
      > $outputdir/target.config
    fi
    cat diffconfig2.config > $outputdir/other.config
    sed -n "/^EXT_PACKAGES/p" $build_dir/../buildconfig.config > $outputdir/OpenWrt-K/extpackages.config
    echo "openwrt_tag/branch=$(grep "^OPENWRT_TAG_BRANCH=" $build_dir/../buildconfig.config|sed  "s/OPENWRT_TAG_BRANCH=//")" > $outputdir/OpenWrt-K/compile.config
    echo "kmod_compile_exclude_list=$(grep "^kmod_compile_exclude_list=" $build_dir/../buildconfig.config|sed  "s/kmod_compile_exclude_list=//")" >> $outputdir/OpenWrt-K/compile.config
    echo "use_cache=$(grep "^use_cache=" $build_dir/../buildconfig.config|sed  "s/use_cache=//")" >> $outputdir/OpenWrt-K/compile.config
    echo "ipaddr=$(grep "^ipaddr=" $build_dir/../buildconfig.config|sed -e "s/ipaddr=//")" > $outputdir/OpenWrt-K/openwrtext.config
    echo "timezone=$(grep "^timezone=" $build_dir/../buildconfig.config|sed -e "s/timezone=//")" >> $outputdir/OpenWrt-K/openwrtext.config
    echo "zonename=$(grep "^zonename=" $build_dir/../buildconfig.config|sed -e "s/zonename=//")" >> $outputdir/OpenWrt-K/openwrtext.config
    echo "golang_version=$(grep "^golang_version=" $build_dir/../buildconfig.config|sed -e "s/golang_version=//")" >> $outputdir/OpenWrt-K/openwrtext.config
    # 输出配置文件
    [[ -d $build_dir/../config/$OpenWrt_K_config ]] && rm -rf $build_dir/../config/$OpenWrt_K_config
    mkdir -p $build_dir/../config/$OpenWrt_K_config
    cp -RT $outputdir/ $build_dir/../config/$OpenWrt_K_config
    cd $build_dir/../config/$OpenWrt_K_config
    # 显示成功消息框
    whiptail --title "成功" --msgbox "OpenWrt-K配置文件构建完成\n\
    输出目录：$(pwd)\n\
    生成的配置文件请在删除原配置文件后上传至对应文件夹\n\
    当然你也可以在存储库config新建一个文件夹来存放这些文件,然后你的配置名就是新文件夹名\n\
    如果你想使用新的配置编译请在仓库config/OpenWrt.config文件中设置\n\
    选择ok以返回菜单" 13 100
    cd $build_dir/..
}

start
