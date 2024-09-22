# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import hashlib
import os
import shutil
import subprocess

from actions_toolkit import core

from .logger import logger
from .paths import paths


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


def setup_env(full: bool = False, clear: bool = False) -> None:
    def sudo(*args: str) -> None:
        subprocess.run(["sudo", "-E", *list(args)], stdout=subprocess.PIPE)
    def apt(*args: str) -> None:
        subprocess.run(["sudo", "-E", "apt-get", "-y", *list(args)], stdout=subprocess.PIPE)
    logger.info("开始准备编译环境%s...", f"(full={full}, clear={clear})")
    # https://github.com/community/community/discussions/47863
    sudo("apt-mark", "hold", "grub-efi-amd64-signed")
    # 1. 更新包列表
    logger.info("更新包列表")
    apt("update")
    # 2.删除不需要的包
    if clear:
        logger.info("删除不需要的包")
        try:
            apt("purge", "azure-cli*", "docker*", "ghc*", "zulu*", "llvm*", "firefox", "google*", "dotnet*",
                "powershell*", "openjdk*", "mysql*", "php*", "mongodb*", "dotnet*", "snap*", "moby*")
        except subprocess.CalledProcessError:
            logger.exception("删除不需要的包时发生错误")

    if full:
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
    if clear:
        # 清理空间
        logger.info("清理空间")
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
        sudo("mount", "-o", "compress=zstd", lv_devname, paths.root)
        sudo("chown", "-R", "runner:runner", paths.root)

        # 打印剩余空间
        total, used, free = shutil.disk_usage(paths.root)
        logger.info(f"工作区空间使用情况: {used / (1024**3):.2f}/{total / (1024**3):.2f}GB,剩余:  {free / (1024**3):.2f}GB")


def apply_patch(patch: str, target: str) -> bool:
    result = subprocess.run(["patch", "-p1", "-d", target],
                            input=patch,
                            text=True,
                            capture_output=True,
    )
    return result.returncode == 0


def hash_dirs(directories: list[str] | tuple[str,...], hash_algorithm: str = 'sha256') -> str:
    """计算整个目录的哈希值"""
    hash_obj = hashlib.new(hash_algorithm)

    # 遍历目录中的所有文件和子目录
    for directory in directories:
        for root, _, files in os.walk(directory):
            for name in sorted(files):
                with open(os.path.join(root, name), 'rb') as f:
                    while chunk := f.read(8192):
                        hash_obj.update(chunk)

    return hash_obj.hexdigest()
