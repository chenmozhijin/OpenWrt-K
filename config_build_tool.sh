#!/usr/bin/env bash
#   Copyright (C) 2023  沉默の金

trap 'rm -rf "$TMPDIR"' EXIT
TMPDIR=$(mktemp -d) || exit 1

function start() {
    install_dependencies
    if [ ! -e "buildconfig.config" ]; then
        input_parameters
    fi
    check_ext_packages_config
    while true; do
        menu
        exitstatus=$?
        if [ $exitstatus -ne 6 ]; then
            break
        fi
    done
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
    if ! type uniq  ; then
        echo "未找到uniq命令"
        exit 1
    fi
    if ! type sort ; then
        echo "未找到sort命令"
        exit 1
    fi
}

function detect_github_api_rate_limit() {
remaining_requests=$(curl -s -L -i https://api.github.com/users/octocat|sed -n "/^x-ratelimit-remaining:/p"|sed "s/.*: //"| awk '{print int($0)}') || network_error
if [ "$remaining_requests" -lt "3" ]; then
    reset_time=$(date -d @$(curl -s -L -i https://api.github.com/users/octocat|sed -n "/^x-ratelimit-reset:/p"|sed "s/.*: //") +"%Y-%m-%d %H:%M:%S") || network_error
    echo "超出github的 API 速率限制,请等待到"$reset_time
fi
}

function input_parameters() {
    detect_github_api_rate_limit
    curl -s -L https://api.github.com/repos/openwrt/openwrt/tags|sed -n  '/^    "name": "/p'|sed -e 's/    "name": "//g' -e 's/",//g'> $TMPDIR/tagbranch.list || network_error
    curl -s -L https://api.github.com/repos/openwrt/openwrt/branches|sed -n  '/^    "name": "/p'|sed -e 's/    "name": "//g' -e 's/",//g'>> $TMPDIR/tagbranch.list || network_error
    latest_tag=$(curl -s -L https://api.github.com/repos/openwrt/openwrt/tags|sed -n  '/^    "name": "/p'|sed -e 's/    "name": "//g' -e 's/",//g'| sed -n '1p')
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
    OpenWrt_K_url="$(whiptail --title "Enter the repository address" --inputbox "$inputbox" 10 60 https://github.com/chenmozhijin/OpenWrt-K 3>&1 1>&2 2>&3|sed  -e 's/^[ \t]*//g' -e's/[ \t]*$//g')"
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ "$(grep -c "^build_dir=" buildconfig.config)" -eq '1' ];then
            build_dir=$(grep "^build_dir=" buildconfig.config|sed -e "s/build_dir=//")
            rm -rf $build_dir/OpenWrt-K
            whiptail --title "Message box" --msgbox "请重新准备运行环境" 10 80
        fi
        whiptail --title "Message box" --msgbox "你选择的OpenWrt branch或tag为: $OPENWRT_TAG_BRANCHE\n选择的OpenWrt-K存储库地址为: $OpenWrt_K_url" 10 80
        echo "警告：请勿手动修改本文件" > buildconfig.config
        echo OPENWRT_TAG_BRANCHE=$OPENWRT_TAG_BRANCHE >> buildconfig.config
        echo OpenWrt_K_url=$OpenWrt_K_url >> buildconfig.config
    else
        echo "你选择了退出"
        exit 0
    fi
    config_ext_packages
}

function import_ext_packages_config() {
    OPTION=$(whiptail --title "配置拓展软件包" --menu "选择导入拓展软件包配置的方式，如果你没有拓展软件包配置你将只能构建openwrt官方源码与feeds自带的软件包。你现有的拓展软件包配置会被覆盖。" 15 60 4 \
    "1" "从原OpenWrt-K仓库导入拓展软件包配置" \
    "2" "从你指定的OpenWrt-K仓库导入拓展软件包配置"  3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus != 0 ]; then
        return 11
    fi
    if [ $OPTION = 1 ]; then
        DOWNLOAD_URL=https://raw.githubusercontent.com/chenmozhijin/OpenWrt-K/main/config/OpenWrt-K/extpackages.config
    elif [ $OPTION = 2 ]; then
        OpenWrt_K_url=$(grep "^OpenWrt_K_url=" buildconfig.config|sed  "s/OpenWrt_K_url=//")
        OpenWrt_K_repo=$(echo $OpenWrt_K_url|sed -e "s/https:\/\/github.com\///" -e "s/\/$//" )
        branch=$(curl -s -L --retry 3 https://api.github.com/repos/$OpenWrt_K_repo|grep "\"default_branch\": \""|grep "\","| sed -e "s/  \"default_branch\": \"//g" -e "s/\",//g" )
        [[ -z "$branch" ]] && echo "错误获取分支失败" && exit 1
        DOWNLOAD_URL=https://raw.githubusercontent.com/$OpenWrt_K_repo/$branch/config/OpenWrt-K/extpackages.config
    else
        echo "错误的选项"
        exit 1
    fi
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
        echo "拓展软件包配置下载未知错误，下载的文件中为检测到配置文件 ，下载链接：$DOWNLOAD_URL"
        exit 1
    fi
    sed -i "/^EXT_PACKAGES/d" buildconfig.config || exit 1
    cat $TMPDIR/config_ext_packages/extpackages.config >> buildconfig.config
    [[  -e $TMPDIR/config_ext_packages/extpackages.config ]] && rm -rf $TMPDIR/config_ext_packages/extpackages.config
}

function check_ext_packages_config() {
    if [ "$(grep -c "^EXT_PACKAGES" buildconfig.config)" -eq '0' ];then
        import_ext_packages_config
        if [ "$?" -eq '11' ];then
            echo "你选择了退出"
            exit 0
        fi
    fi
    NUMBER_OF_PKGS=$(grep -c "^EXT_PACKAGES_NAME\[" buildconfig.config)
    if [ "$(grep -c "^EXT_PACKAGES_NAME\[$NUMBER_OF_PKGS\]" buildconfig.config)" -eq "0" ];then #最后一个不存在
        whiptail --title "Message box" --msgbox "检测到拓展软件包配置有错误，点击ok重新导入（你现有的拓展软件包配置会被覆盖）" 10 60 #最后一个后还有
        sed -i "/^EXT_PACKAGES/d" buildconfig.config || exit 1
        import_ext_packages_config
        if [ "$?" -eq '11' ];then
            echo "你选择了退出"
            exit 0
        fi
    elif [ "$(grep -c "^EXT_PACKAGES_NAME\[$(( $NUMBER_OF_PKGS+1 ))\]" buildconfig.config)" -ne "0" ];then
        whiptail --title "Message box" --msgbox "检测到拓展软件包配置有错误，点击ok重新导入（你现有的拓展软件包配置会被覆盖）" 10 60
        sed -i "/^EXT_PACKAGES/d" buildconfig.config || exit 1
        import_ext_packages_config
        if [ "$?" -eq '11' ];then
            echo "你选择了退出"
            exit 0
        fi
    fi
}

function config_ext_packages() {
    check_ext_packages_config
    while true; do
        config_ext_packages_mainmenu
        exitstatus=$?
        if [ $exitstatus -ne 6 ]; then
            break
        fi
    done
}

function config_ext_packages_mainmenu() {
    NUMBER_OF_PKGS=$(grep -c "^EXT_PACKAGES_NAME\[" buildconfig.config)
    mkdir -p $TMPDIR/config_ext_packages || exit 1
    rm -rf $TMPDIR/config_ext_packages/menu $TMPDIR/config_ext_packages/submenu
    n=1
    while [ "$n" -le $NUMBER_OF_PKGS ]; do
    echo "$n $(grep "^EXT_PACKAGES_NAME\[$n\]" buildconfig.config| sed -e "s/.*=\"//g" -e "s/\"//g")" >> $TMPDIR/config_ext_packages/menu
    n=$(( n+1 ))
    done
    echo "$n 添加一个拓展软件包 " >> $TMPDIR/config_ext_packages/menu
    n=$(( n+1 ))
    echo "$n 重新导入拓展软件包配置 " >> $TMPDIR/config_ext_packages/menu
    OPTION=$(whiptail --title "OpenWrt-k配置构建工具-配置拓展软件包菜单" --menu "选择你要修改的配置拓展软件包或选择。请不要重复添加拓展软件包，也不要忘记添加依赖或删除其他包的依赖。如果你已经准备完运行环境请重新载入拓展软件包。" 25 70 15 $(cat $TMPDIR/config_ext_packages/menu) 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ $OPTION = "$(( $NUMBER_OF_PKGS+1 ))" ]; then  #添加一个拓展软件包
            while true; do
                NEW_EXT_PKG_NAME=$(whiptail --title "输入拓展软件包名" --inputbox "此包名将用于创建包存放文件夹，请勿输入空格斜杠或与其他软件包重名" 10 60 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ -z "$NEW_EXT_PKG_NAME" ]; then
                    whiptail --title "Message box" --msgbox "拓展软件包名不能为空" 10 60
                elif [ "$(echo "$NEW_EXT_PKG_NAME"|grep -c "[!@#$%^&:*=+\`~\'\"\(\)/ ]")" -ne '0' ];then
                    whiptail --title "Message box" --msgbox "拓展软件包名中有非法字符" 10 60
                elif [ "$(sed -n "/^EXT_PACKAGES_NAME/p" buildconfig.config | sed -e "s/.*=\"//g" -e "s/\"//g"|grep -c "^$NEW_EXT_PKG_NAME$")" -ne '0' ];then
                    whiptail --title "Message box" --msgbox "此拓展软件包名与其他软件包重名" 10 60
                else
                    break
                fi
            done
            while true; do
                NEW_EXT_PKG_PATH=$(whiptail --title "输入拓展软件包在存储库中的目录" --inputbox "输入包与存储库的相对位置，例如一个包在存储库根目录的luci-app-xxx文件夹下则输入luci-app-xxx，如果包就在根目录着可以不输入。" 10 60 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ "$(echo "$NEW_EXT_PKG_PATH"|grep -c "[!@#$%^&:*=+\`~\'\"\(\) ]")" -ne '0' ];then
                    whiptail --title "Message box" --msgbox "拓展软件包目录中有非法字符" 10 60
                else
                    break
                fi
            done
            while true; do
                NEW_EXT_PKG_REPOSITORIE=$(whiptail --title "输入拓展软件包所在存储库" --inputbox "输入https的存储库地址，无需加“.git”，例如：“https://github.com/chenmozhijin/turboacc”" 10 60 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ -z "$NEW_EXT_PKG_REPOSITORIE" ]; then
                    whiptail --title "Message box" --msgbox "拓展软件包所在存储库不能为空" 10 60
                elif [ "$(echo "$NEW_EXT_PKG_REPOSITORIE"|grep -c "[!$^*+\`~\'\"\(\) ]")" -ne '0' ];then
                    whiptail --title "Message box" --msgbox "拓展软件包所在存储库中有非法字符" 10 60
                elif [ "$(echo "$NEW_EXT_PKG_REPOSITORIE"|grep -c "^http[s]\{0,1\}://")" -eq '0' ]  || [ "$(echo "$NEW_EXT_PKG_REPOSITORIE"|grep -c ".")" -eq '0' ] ;then
                    whiptail --title "Message box" --msgbox "拓展软件包所在存储库链接不正常" 10 60
                else
                    break
                fi
            done
            while true; do
                NEW_EXT_PKG_BRANCHE=$(whiptail --title "输入拓展软件包所在分支" --inputbox "输入软件包在存储库的分支，一般不输入默认留空使用默认分支即可" 10 60 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ "$(echo "$NEW_EXT_PKG_BRANCHE"|grep -c "[!@#$%^&:*=+\`~\'\"\(\)/ ]")" -ne '0' ];then
                    whiptail --title "Message box" --msgbox "拓展软件包所在分支中有非法字符" 10 60
                else
                    break
                fi
            done
            NEW_EXT_PKG_NUMBER=$(( $NUMBER_OF_PKGS+1 ))
            sed -i "$(sed -n '/^EXT_PACKAGES/=' buildconfig.config|sed -n '$p')a EXT_PACKAGES_NAME\[$NEW_EXT_PKG_NUMBER\]=\"$NEW_EXT_PKG_NAME\"" buildconfig.config
            sed -i "$(sed -n '/^EXT_PACKAGES/=' buildconfig.config|sed -n '$p')a EXT_PACKAGES_PATH\[$NEW_EXT_PKG_NUMBER\]=\"$NEW_EXT_PKG_PATH\"" buildconfig.config
            sed -i "$(sed -n '/^EXT_PACKAGES/=' buildconfig.config|sed -n '$p')a EXT_PACKAGES_REPOSITORIE\[$NEW_EXT_PKG_NUMBER\]=\"$NEW_EXT_PKG_REPOSITORIE\"" buildconfig.config
            sed -i "$(sed -n '/^EXT_PACKAGES/=' buildconfig.config|sed -n '$p')a EXT_PACKAGES_BRANCHE\[$NEW_EXT_PKG_NUMBER\]=\"$NEW_EXT_PKG_BRANCHE\"" buildconfig.config
            return 6
        elif [ $OPTION = "$(( $NUMBER_OF_PKGS+2 ))" ]; then  #重新配置软件包数与拓展软件包
            sed -i "/^EXT_PACKAGES/d" buildconfig.config
            import_ext_packages_config
        elif [ $OPTION -le "$(( $NUMBER_OF_PKGS ))" ]; then  #编辑配置
            while true; do
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

function config_ext_packages_submenu() {
    NUMBER_OF_PKGS=$(grep -c "^EXT_PACKAGES_NAME\[" buildconfig.config)
    EXT_PKG_NAME=$(grep "^EXT_PACKAGES_NAME\[$OPTION\]" buildconfig.config| sed -e "s/.*=\"//g" -e "s/\"//g")
    EXT_PKG_PATH=$(grep "^EXT_PACKAGES_PATH\[$OPTION\]" buildconfig.config| sed -e "s/.*=\"//g" -e "s/\"//g")
    EXT_PKG_REPOSITORIE=$(grep "^EXT_PACKAGES_REPOSITORIE\[$OPTION\]" buildconfig.config| sed -e "s/.*=\"//g" -e "s/\"//g")
    EXT_PKG_BRANCHE=$(grep "^EXT_PACKAGES_BRANCHE\[$OPTION\]" buildconfig.config| sed -e "s/.*=\"//g" -e "s/\"//g")
    rm -rf $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    mkdir $TMPDIR/config_ext_packages/submenu/
    echo "1 包名：$EXT_PKG_NAME" >> $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    if [ -z $EXT_PKG_PATH ]; then
        echo "2 包在存储库中的目录：存储库根目录（空）" >> $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    else
        echo "2 包在存储库中的目录：$EXT_PKG_PATH" >> $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    fi
    echo "3 包所在存储库：$EXT_PKG_REPOSITORIE" >> $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    if [ -z $EXT_PKG_BRANCHE ]; then
        echo "4 包所在分支：默认分支（空）" >> $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    else
        echo "4 包所在分支：$EXT_PKG_BRANCHE" >> $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    fi
    echo "5 删除此拓展包" >> $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME
    SUBOPTION=$(whiptail --title "编辑$EXT_PKG_NAME" --menu "选择你要修改项目或选择Cancel返回" 15 90 5 $(cat $TMPDIR/config_ext_packages/submenu/$EXT_PKG_NAME) 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ "$exitstatus" = "1" ]; then
        echo "你选择了退出"
        return 0
    fi
    case "${SUBOPTION}" in
        1)
            while true; do
                NEW_EXT_PKG_NAME=$(whiptail --title "编辑拓展软件包名" --inputbox "此包名将用于创建包存放文件夹，请勿输入空格斜杠或与其他软件包重名" 10 60 $EXT_PKG_NAME 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ -z "$NEW_EXT_PKG_NAME" ]; then
                    whiptail --title "Message box" --msgbox "拓展软件包名不能为空" 10 60
                elif [ "$(echo "$NEW_EXT_PKG_NAME"|grep -c "[!@#$%^&:*=+\`~\'\"\(\)/ ]")" -ne '0' ];then
                    whiptail --title "Message box" --msgbox "拓展软件包名中有非法字符" 10 60
                elif [ "$(sed -n "/^EXT_PACKAGES_NAME/p" buildconfig.config | sed -e "s/.*=\"//g" -e "s/\"//g"|grep -c "^$NEW_EXT_PKG_NAME$")" -ne '0' ];then
                    whiptail --title "Message box" --msgbox "此拓展软件包名与其他软件包重名" 10 60
                else
                    break
                fi
            done
            sed -i "/^EXT_PACKAGES_NAME\[$OPTION\]/s/=\".*/=\"$NEW_EXT_PKG_NAME\"/g" buildconfig.config
            return 6
            ;;
        2)
            while true; do
                NEW_EXT_PKG_PATH=$(whiptail --title "编辑拓展软件包在存储库中的目录" --inputbox "输入包与存储库的相对位置，例如一个包在存储库根目录的luci-app-xxx文件夹下则输入luci-app-xxx，如果包就在根目录着可以不输入" 10 60 $EXT_PKG_PATH 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ "$(echo "$NEW_EXT_PKG_PATH"|grep -c "[!@#$%^&:*=+\`~\'\"\(\) ]")" -ne '0' ];then
                    whiptail --title "Message box" --msgbox "拓展软件包目录中有非法字符" 10 60
                else
                    break
                fi
            done
            sed -i "s@EXT_PACKAGES_PATH\[$OPTION\]=\".*@EXT_PACKAGES_PATH\[$OPTION\]=\"$NEW_EXT_PKG_PATH\"@g" buildconfig.config
            return 6
            ;;
        3)
            while true; do
                NEW_EXT_PKG_REPOSITORIE=$(whiptail --title "编辑拓展软件包所在存储库" --inputbox "输入https的存储库地址，无需加“.git”，例如：“https://github.com/chenmozhijin/turboacc”" 10 60 $EXT_PKG_REPOSITORIE 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ -z "$NEW_EXT_PKG_REPOSITORIE" ]; then
                    whiptail --title "Message box" --msgbox "拓展软件包所在存储库不能为空" 10 60
                elif [ "$(echo "$NEW_EXT_PKG_REPOSITORIE"|grep -c "[!$^*+\`~\'\"\(\) ]")" -ne '0' ];then
                    whiptail --title "Message box" --msgbox "拓展软件包所在存储库中有非法字符" 10 60
                elif [ "$(echo "$NEW_EXT_PKG_REPOSITORIE"|grep -c "^http[s]\{0,1\}://")" -eq '0' ]  || [ "$(echo "$NEW_EXT_PKG_REPOSITORIE"|grep -c ".")" -eq '0' ] ;then
                    whiptail --title "Message box" --msgbox "拓展软件包所在存储库链接不正常" 10 60
                else
                    break
                fi
            done
            sed -i "s@EXT_PACKAGES_REPOSITORIE\[$OPTION\]=\".*@EXT_PACKAGES_REPOSITORIE\[$OPTION\]=\"$NEW_EXT_PKG_REPOSITORIE\"@g" buildconfig.config
            return 6
            ;;
        4)
            while true; do
                NEW_EXT_PKG_BRANCHE=$(whiptail --title "编辑拓展软件包所在分支" --inputbox "输入软件包在存储库的分支，一般不输入默认留空使用默认分支即可" 10 60 $EXT_PKG_BRANCHE 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [ $exitstatus != 0 ]; then
                    echo "你选择了退出"
                    return 6
                elif [ "$(echo "$NEW_EXT_PKG_BRANCHE"|grep -c "[!@#$%^&:*=+\`~\'\"\(\)/ ]")" -ne '0' ];then
                    whiptail --title "Message box" --msgbox "拓展软件包所在分支中有非法字符" 10 60
                else
                    break
                fi
            done
            sed -i "/^EXT_PACKAGES_BRANCHE\[$OPTION\]/s/=\".*/=\"$NEW_EXT_PKG_BRANCHE\"/g" buildconfig.config
            return 6
            ;;
        5)
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

function network_error() {
    whiptail --title "Message box" --msgbox "获取最新OpenWrt branch与tag失败,请检查你的网络环境是否能正常与github通信。" 10 60
    exit 1
}

function menu() {
    OPTION=$(whiptail --title "OpenWrt-k配置构建工具" --menu "选择你要执行的步骤或选择Cancel退出" 16 80 10 \
    "1" "准备运行环境" \
    "2" "打开openwrt配置菜单" \
    "3" "构建配置" \
    "4" "载入OpenWrt-K默认config" \
    "5" "清除所有openwrt配置" \
    "6" "清除运行环境" \
    "7" "重新配置OpenWrt-K存储库地址、OpenWrt branch或tag与配置拓展软件包" \
    "8" "配置拓展软件包" \
    "9" "重新载入拓展软件包" \
    "10" "关于" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        if [ "$OPTION" = "1" ]; then
            if (whiptail --title "Yes/No Box" --yesno "这将会下载openwrt以及其插件的源码，请确保你拥有良好的网络环境。选择yes继续no返回菜单。" 10 60) then
                prepare
                exitstatus=$?
                if [ $exitstatus = 4 ]; then
                    whiptail --title "Message box" --msgbox "下载失败,请检查你的网络环境是否正常、OpenWrt-K与拓展软件包存储库地址是否正确。如果不是第一次准备请尝试清除运行环境" 10 60
                elif [ $exitstatus = 7 ]; then
                    whiptail --title "Message box" --msgbox "git checkot执行失败，请尝试清除运行环境" 10 60
                fi
            fi
            return 6
        elif [ "$OPTION" = "6" ]; then
            if  (whiptail --title "Yes/No Box" --yesno "这将会删除你未生成的配置与下载的文件。选择yes继续no返回菜单。" 10 60) then
                clearrunningenvironment
            fi
            return 6
        elif [ "$OPTION" = "7" ]; then
            input_parameters
            return 6
        elif [ "$OPTION" = "8" ]; then
            config_ext_packages
            return 6
        elif [ "$OPTION" = "10" ]; then
            about
            return 6
        else
            if [ "$(grep -c "^build_dir=" buildconfig.config)" -eq '1' ];then
                if [ -e "$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")/openwrt/feeds/telephony.index" ] && [ -e "$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")/OpenWrt-K" ] ;then
                  case "${OPTION}" in
                    2)
                      menuconfig
                      return 6
                      ;;
                    3)
                        if  (whiptail --title "Yes/No Box" --yesno "这将会覆盖你已生成的配置。选择yes继续no返回菜单。" 10 60) then
                            build
                        fi
                        return 6
                      ;;
                    4)
                        if  (whiptail --title "Yes/No Box" --yesno "这将会覆盖你的现有配置。选择yes继续no返回菜单。" 10 60) then
                            importopenwrt_kconfig
                        fi
                        return 6
                        ;;
                    5)
                        if  (whiptail --title "Yes/No Box" --yesno "这将会删除你的现有配置。选择yes继续no返回菜单。" 10 60) then
                            clearconfig
                        fi
                        return 6
                        ;;
                    9)
                        if (whiptail --title "Yes/No Box" --yesno "这将会重新下载拓展软件包源码，请确保你拥有良好的网络环境。选择yes继续no返回菜单。" 10 60) then
                            build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
                            import_ext_packages
                            if [ $exitstatus = 4 ]; then
                                whiptail --title "Message box" --msgbox "下载失败,请检查你的网络环境是否正常与拓展软件包存储库地址是否正确。" 10 60
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
                    sed -i "/^OpenWrt_K_dir=/d" buildconfig.config
                    fi
                    whiptail --title "Message box" --msgbox "你还没有准备运行环境，选择ok以返回菜单。" 10 60
                    return 6
                fi
            else
                whiptail --title "Message box" --msgbox "你还没有准备运行环境，选择ok以返回菜单。" 10 60
                return 6
            fi
        fi
    else
        echo "你选择了退出"
        return 0
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
        sed -i "\$a\build_dir=$build_dir" $build_dir/../buildconfig.config
        openwrt_dir=$build_dir/openwrt
    fi
    OpenWrt_K_url=$(grep "^OpenWrt_K_url=" $build_dir/../buildconfig.config|sed  "s/OpenWrt_K_url=//")
    OpenWrt_K_dir=$build_dir/$(echo $OpenWrt_K_url|sed -e "s/https:\/\///" -e "s/\/$//" -e "s/[.\/a-zA-Z0-9]\{1,111\}\///g" -e "s/\ .*//g")
    OPENWRT_TAG_BRANCHE=$(grep "^OPENWRT_TAG_BRANCHE=" $build_dir/../buildconfig.config|sed  "s/OPENWRT_TAG_BRANCHE=//")
    if [ -d "$OpenWrt_K_dir" ]; then
        git -C $OpenWrt_K_dir pull || return 4
    else
        git clone $OpenWrt_K_url $OpenWrt_K_dir || return 4
    fi
    if [ -d "$openwrt_dir" ]; then
        cd $openwrt_dir
        if ! [[ "$OPENWRT_TAG_BRANCHE" =~ ^v.* ]]; then
            git checkout $OPENWRT_TAG_BRANCHE || return 4
            git -C $openwrt_dir pull || return 4
        else
            if ! [[ "$(git branch |sed -n "/^\* /p"|sed "s/\* //")" =~ ^\(HEAD\ detached\ at\ v.* ]]; then
                git -C $openwrt_dir pull || return 4
                git checkout $OPENWRT_TAG_BRANCHE
                exitstatus=$?
                if [ $exitstatus -ne 0 ]; then
                    rm -rf $openwrt_dir
                    git clone https://github.com/openwrt/openwrt $openwrt_dir || return 4
                    cd $openwrt_dir
                    git checkout $OPENWRT_TAG_BRANCHE || return 7
                fi
            fi
        fi
    else
        git clone https://github.com/openwrt/openwrt $openwrt_dir || return 4
        cd $openwrt_dir
        git checkout $OPENWRT_TAG_BRANCHE || return 7
    fi
    #克隆拓展软件包仓库
    import_ext_packages
    exitstatus=$?
    if [ $exitstatus = 4 ]; then
        return 4
    fi
    #修复问题
    cd $openwrt_dir
    sed -i 's/^  DEPENDS:= +kmod-crypto-manager +kmod-crypto-pcbc +kmod-crypto-fcrypt$/  DEPENDS:= +kmod-crypto-manager +kmod-crypto-pcbc +kmod-crypto-fcrypt +kmod-udptunnel4 +kmod-udptunnel6/' package/kernel/linux/modules/netsupport.mk
    sed -i 's/^	dnsmasq \\$/	dnsmasq-full \\/g' ./include/target.mk
    sed -i 's/^	b43-fwsquash.py "$(CONFIG_B43_FW_SQUASH_PHYTYPES)" "$(CONFIG_B43_FW_SQUASH_COREREVS)"/	$(TOPDIR)\/tools\/b43-tools\/files\/b43-fwsquash.py "$(CONFIG_B43_FW_SQUASH_PHYTYPES)" "$(CONFIG_B43_FW_SQUASH_COREREVS)"/' ./package/kernel/mac80211/broadcom.mk
    ./scripts/feeds update -a  || return 4
    ./scripts/feeds install -a
    [[ -d $openwrt_dir ]] && rm -rf .config
    [[ -d $openwrt_dir ]] && rm -rf $openwrt_dir/tmp
    cat $OpenWrt_K_dir/config/target.config >> .config
    cat $OpenWrt_K_dir/config/luci.config >> .config
    cat $OpenWrt_K_dir/config/utilities.config >> .config
    cat $OpenWrt_K_dir/config/network.config >> .config
    cat $OpenWrt_K_dir/config/other.config >> .config
    cat $OpenWrt_K_dir/config/kmod.config >> .config
    cat $OpenWrt_K_dir/config/image.config >> .config
    make defconfig
    sed -i 's/256/1024/' ./target/linux/$(sed -n '/CONFIG_TARGET_BOARD/p' .config | sed -e 's/CONFIG_TARGET_BOARD\=\"//' -e 's/\"//')/image/Makefile
    cd $build_dir/..	
    whiptail --title "Message box" --msgbox "准备完成，选择ok以返回菜单。" 10 60
    return 0
}

function import_ext_packages() {
    [[ -d $build_dir/extpackages ]] && rm -rf $build_dir/extpackages
    [[ -d $TMPDIR/extpackages_prepare ]] && rm -rf $TMPDIR/extpackages_prepare
    EXT_PKGS_PREP_PATH=$TMPDIR/extpackages_prepare
    EXT_PKGS_DL_PATH=$build_dir/extpackages/dl
    EXT_PKGS_PATH=$build_dir/extpackages/extpackages
    EXT_PKGS_CONFIG=$EXT_PKGS_PREP_PATH/extpackages.config
    mkdir -p $EXT_PKGS_PREP_PATH $EXT_PKGS_PATH $EXT_PKGS_DL_PATH
    sed -n "/^EXT_PACKAGES/p" $build_dir/../buildconfig.config > $EXT_PKGS_CONFIG
    NUMBER_OF_PKGS=$(grep -c "^EXT_PACKAGES_NAME\[" $EXT_PKGS_CONFIG)
    n=1
    while [ "$n" -le $NUMBER_OF_PKGS ]; do
        EXT_PKG_REPOSITORIE=$(grep "^EXT_PACKAGES_REPOSITORIE\[$n\]" $EXT_PKGS_CONFIG| sed -e "s/.*=\"//g" -e "s/\"//g")
        EXT_PKG_BRANCHE=$(grep "^EXT_PACKAGES_BRANCHE\[$n\]" $EXT_PKGS_CONFIG| sed -e "s/.*=\"//g" -e "s/\"//g")
        echo "REPOSITORIE=$EXT_PKG_REPOSITORIE BRANCHE=$EXT_PKG_BRANCHE" >> $EXT_PKGS_PREP_PATH/extpackagesbr.config
        n=$(( n+1 ))
    done
    sort $EXT_PKGS_PREP_PATH/extpackagesbr.config|uniq > $EXT_PKGS_PREP_PATH/clone.config
    sed -i -e "s/BRANCHE=$//g" $EXT_PKGS_PREP_PATH/clone.config
    sed -i -e "s/BRANCHE=/--branch /g" $EXT_PKGS_PREP_PATH/clone.config
    NUMBER_OF_CLONES=$(grep -c "REPOSITORIE=" $EXT_PKGS_PREP_PATH/clone.config)
    sed -i "s/^REPOSITORIE=//g" $EXT_PKGS_PREP_PATH/clone.config
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
    echo "开始整理拓展软件包"
    n=1
    while [ "$n" -le $NUMBER_OF_PKGS ]; do
        NUMBER_OF_PKGS=$(grep -c "^EXT_PACKAGES_NAME\[" $EXT_PKGS_CONFIG)
        EXT_PKG_NAME=$(grep "^EXT_PACKAGES_NAME\[$n\]" $EXT_PKGS_CONFIG| sed -e "s/.*=\"//g" -e "s/\"//g")
        EXT_PKG_PATH=$(grep "^EXT_PACKAGES_PATH\[$n\]" $EXT_PKGS_CONFIG| sed -e "s/.*=\"//g" -e "s/\"//g")
        EXT_PKG_REPOSITORIE=$(grep "^EXT_PACKAGES_REPOSITORIE\[$n\]" $EXT_PKGS_CONFIG| sed -e "s/.*=\"//g" -e "s/\"//g")
        EXT_PKG_BRANCHE=$(grep "^EXT_PACKAGES_BRANCHE\[$n\]" $EXT_PKGS_CONFIG| sed -e "s/.*=\"//g" -e "s/\"//g")
        EXT_PKG_REPO_PATH=$(echo "$EXT_PKG_REPOSITORIE" | sed -e "s/$ //g" -e "s/ .*//g" -e "s@.*://@@g" -e "s/^[a-zA-Z.]\{1,111\}\///" -e "s/\/$//g")
        if [ -z "$EXT_PKG_BRANCHE" ];then
            EXT_PKG_BRANCHE="default_branch"
        fi
        mkdir -p $EXT_PKGS_PATH/$EXT_PKG_NAME
        cp -RT $EXT_PKGS_DL_PATH/$EXT_PKG_BRANCHE/$EXT_PKG_REPO_PATH/$EXT_PKG_PATH $EXT_PKGS_PATH/$EXT_PKG_NAME
        n=$(( n+1 ))
    done
    cd $EXT_PKGS_PATH
    #修复包
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
    [[ -d $openwrt_dir ]] && rm -rf $openwrt_dir/package/extpackages
    mkdir -p $openwrt_dir/package/extpackages
    cp -RT $EXT_PKGS_PATH $openwrt_dir/package/extpackages
    rm -rf $EXT_PKGS_PREP_PATH $build_dir/extpackages
    cd $build_dir/..
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
    sed -i 's/256/1024/' ./target/linux/$(sed -n '/CONFIG_TARGET_BOARD/p' .config | sed -e 's/CONFIG_TARGET_BOARD\=\"//' -e 's/\"//')/image/Makefile
    [[ -d $TMPDIR/targetconfig ]] && rm -rf $TMPDIR/targetconfig
    cd $build_dir/..
}

function importopenwrt_kconfig() {
    build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
    openwrt_dir=$build_dir/openwrt
    OpenWrt_K_url=$(grep "^OpenWrt_K_url=" $build_dir/../buildconfig.config|sed  "s/OpenWrt_K_url=//")
    OpenWrt_K_dir=$build_dir/$(echo $OpenWrt_K_url|sed -e "s/https:\/\///" -e "s/\/$//" -e "s/[.\/a-zA-Z0-9]\{1,111\}\///g" -e "s/\ .*//g")
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
}

function clearrunningenvironment() {
    build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
    cd $build_dir/..
    rm -rf $build_dir
    sed -i  "/^build_dir=/d" buildconfig.config
}

function about() {
    whiptail --title "关于" --msgbox "这是一个用于生成OpenWrt-K配置文件的脚本\n\
    Copyright (C) 2023  沉默の金, All rights reserved.\n" 10 60
}

function build () {
    #准备工作
    build_dir=$(grep "^build_dir=" buildconfig.config|sed  "s/build_dir=//")
    openwrt_dir=$build_dir/openwrt
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
    sed -n "/^EXT_PACKAGES/p" $build_dir/../buildconfig.config > $outputdir/OpenWrt-K/extpackages.config
    #输出
    [[ -d $build_dir/../config/ ]] && rm -rf $build_dir/../config/
    mkdir -p $build_dir/../config/
    cp -RT $outputdir/ $build_dir/../config/
    cd $build_dir/../config/
    whiptail --title "成功" --msgbox "OpenWrt-K配置文件构建完成\n\
    输出目录：$(pwd)\n\
    如果你修改了OpenWrt branch或tag请在OpenWrt-K.Config做相应修改\n\
    其他生成的配置文件请在config文件夹做相应修改\n\
    选择ok以返回菜单" 13 90
    cd $build_dir/..
}

start
