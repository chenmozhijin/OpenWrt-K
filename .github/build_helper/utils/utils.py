# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import os
import subprocess

from actions_toolkit import core

from .logger import logger


def parse_config(path: str, prefixs: tuple[str,...]|list[str]) -> dict[str, str | list[str] | bool]:
    if not os.path.isfile(path):
        core.set_failed(f"配置文件 {path} 不存在")

    config = {}
    with open(path, encoding="utf-8") as f:
        for prefix in prefixs:
            for line in f:
                if line.startswith(prefix+"="):
                    content = line.split("=")[1].strip()
                    match content.lower():
                        case "true":
                            config[prefix] = True
                        case "false":
                            config[prefix] = False
                        case _:
                            if "," in content:
                                config[prefix] = [v.strip() for v in content.split(",")]
                            else:
                                config[prefix] = content
                    break
            else:
                core.set_failed(f"无法在配置文件 {path} 中找到配置项{prefix}")
    return config


def setup_compilation_environment(build: bool = False) -> None:
    def sudo(*args: str) -> None:
        subprocess.run(["sudo", "-E", *list(args)])
    def apt(*args: str) -> None:
        subprocess.run(["sudo", "-E", "apt-get", "-y", *list(args)])
    logger.info("开始设置编译环境...")
    # https://github.com/community/community/discussions/47863
    sudo("apt-mark", "hold", "grub-efi-amd64-signed")
    # 1. 更新包列表
    logger.info("更新包列表")
    apt("update")
    # 2.删除不需要的包
    if build:
        logger.info("删除不需要的包")
        try:
            apt("purge", "azure-cli*", "docker*", "ghc*", "zulu*", "llvm*", "firefox", "google*", "dotnet*",
                "powershell*", "openjdk*", "mysql*", "php*", "mongodb*", "dotnet*", "snap*", "moby*")
        except subprocess.CalledProcessError:
            logger.exception("删除不需要的包时发生错误")

    if build:
        # 3. 完整更新所有包
        logger.info("完整更新所有包")
        apt("dist-upgrade")
        # 4.安装编译环境
        apt("install", "ack", "antlr3", "aria2", "asciidoc", "autoconf", "automake", "autopoint", "b43-fwcutter", "binutils",
            "bison", "build-essential", "bzip2", "ccache", "cmake", "cpio", "curl", "device-tree-compiler", "fastjar",
            "flex", "gawk", "gettext", "gcc-multilib", "g++-multilib", "git", "gperf", "haveged", "help2man", "intltool",
            "libc6-dev-i386", "libelf-dev", "libglib2.0-dev", "libgmp3-dev", "libltdl-dev", "libmpc-dev", "libmpfr-dev",
            "libncurses5-dev", "libncursesw5-dev", "libreadline-dev", "libssl-dev", "libtool", "lrzsz", "mkisofs", "msmtp",
            "nano", "ninja-build", "p7zip", "p7zip-full", "patch", "pkgconf", "python2.7", "python3-distutils",
            "qemu-utils", "clang", "g++", "rsync", "unzip", "zlib1g-dev", "wget")
    else:
        apt("install", "build-essential", "clang", "flex", "bison", "g++", "gawk", "gcc-multilib", "g++-multilib", "gettext",
            "libncurses5-dev", "libssl-dev", "rsync", "swig", "unzip", "zlib1g-dev", "file", "wget")
    # 5.重载系统
    logger.info("重载系统")
    sudo("systemctl", "daemon-reload")
    # 6.自动删除不需要的包
    logger.info("自动删除不需要的包")
    try:
        apt("autoremove", "--purge")
    except subprocess.CalledProcessError:
        logger.exception("自动删除不需要的包")
    # 7.清理缓存
    logger.info("清理缓存")
    apt("clean")
    # 8.调整时区
    logger.info("调整时区")
    sudo("timedatectl", "set-timezone", "Asia/Shanghai")
    if build:
        # 清理空间
        logger.info("清理空间")
        try:
            sudo("rm", "-rf", "/etc/apt/sources.list.d/*", "/usr/share/dotnet", "/usr/local/lib/android", "/opt/ghc",
                 "/etc/mysql", "/etc/php")
            # 移除 swap 文件
            sudo("swapoff", "-a")
            sudo("rm", "-f", "/mnt/swapfile")

            # 创建根分区映像文件
            root_avail_kb = int(subprocess.check_output(["df", "--block-size=1024", "--output=avail", "/"]).decode().splitlines()[-1])
            root_size_kb = (root_avail_kb - 1048576) * 1024
            sudo("fallocate", "-l", str(root_size_kb), "/root.img")
            root_loop_devname = subprocess.check_output(["sudo", "losetup", "-Pf", "--show", "/root.img"]).decode().strip()

            # 创建物理卷
            sudo("pvcreate", "-f", root_loop_devname)

            # 创建挂载点分区映像文件
            mnt_avail_kb = int(subprocess.check_output(["df", "--block-size=1024", "--output=avail", "/mnt"]).decode().splitlines()[-1])
            mnt_size_kb = (mnt_avail_kb - 102400) * 1024
            sudo("fallocate", "-l", str(mnt_size_kb), "/mnt/mnt.img")
            mnt_loop_devname = subprocess.check_output(["sudo", "losetup", "-Pf", "--show", "/mnt/mnt.img"]).decode().strip()

            # 创建物理卷
            sudo("pvcreate", "-f", mnt_loop_devname)

            # 创建卷组和逻辑卷
            sudo("vgcreate", "vgstorage", root_loop_devname, mnt_loop_devname)
            sudo("lvcreate", "-n", "lvstorage", "-l", "100%FREE", "vgstorage")
            lv_devname = subprocess.check_output(["sudo", "lvscan"]).decode().split("'")[1].strip()

            # 创建文件系统并挂载
            sudo("mkfs.btrfs", "-L", "combinedisk", lv_devname)
            github_workspace = os.environ.get("GITHUB_WORKSPACE", "/github/workspace")
            sudo("mount", "-o", "compress=zstd", lv_devname, github_workspace)
            sudo("chown", "-R", "runner:runner", github_workspace)
            subprocess.run(["df", "-hT", github_workspace])
            sudo("btrfs", "filesystem", "usage", github_workspace)

        except subprocess.CalledProcessError as e:
            logger.exception(f"创建或挂载分区时发生错误: {e}")


def apply_patch(patch: str, target: str) -> bool:
    result = subprocess.run(["patch", "-p1", "-d", target],
                            input=patch,
                            text=True,
                            capture_output=True,
    )
    return result.returncode == 0
