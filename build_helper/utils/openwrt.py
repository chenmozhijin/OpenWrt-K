# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import os
import re
import shutil
import subprocess
import tarfile
from typing import Literal

import pygit2
from actions_toolkit import core

from .logger import logger
from .network import request_get
from .paths import paths
from .utils import apply_patch


class OpenWrtBase:
    def __init__(self, path: str) -> None:
        self.path = path

    def get_arch(self) -> tuple[str | None, str | None]:
        arch = None
        version = None
        if os.path.isfile(os.path.join(self.path, '.config')):
            with open(os.path.join(self.path, '.config')) as f:
                for line in f:
                    if line.startswith('CONFIG_ARCH='):
                        match = re.match(r'^CONFIG_ARCH="(?P<arch>.*)"$', line)
                        if match:
                            arch = match.group("arch")
                    elif line.startswith('CONFIG_arm_'):
                        match = re.match(r'^CONFIG_arm_(?P<ver>[0-9]+)=y$', line)
                        if match:
                            version = match.group("ver")

                    if arch and version:
                        break
        logger.debug("仓库%s的架构为%s,版本为%s", self.path, arch, version)
        return arch, version

    def apply_config(self, config: str) -> None:
        with open(os.path.join(self.path, '.config'), 'w') as f:
            f.write(config)

    def get_target(self) -> tuple[str | None, str | None]:
        target, subtarget = None, None
        if os.path.isfile(os.path.join(self.path, '.config')):
            with open(os.path.join(self.path, '.config')) as f:
                for line in f:
                    if line.startswith('CONFIG_TARGET_BOARD='):
                        match = re.match(r'^CONFIG_TARGET_BOARD="(?P<target>.*)"$', line)
                        if match:
                            target = match.group("target")
                    elif line.startswith('CONFIG_TARGET_SUBTARGET='):
                        match = re.match(r'^CONFIG_TARGET_SUBTARGET="(?P<subtarget>.*)"$', line)
                        if match:
                            subtarget = match.group("subtarget")
                    if target and subtarget:
                        return target, subtarget
        return target, subtarget

    def make(self, target: str, debug: bool = False) -> None:
        args = ['make', target]
        if debug:
            args.extend(["-j1", "V=s"])
        else:
            if not (cpu_count := os.cpu_count()):
                cpu_count = 1
            args.append(f"-j{cpu_count + 1}")
        logger.debug("运行命令：%s", " ".join(args))
        result = subprocess.run(args, cwd=self.path)
        if result.returncode != 0:
            if not debug:
                logger.error("编译失败，尝试使用debug模式重新编译")
                self.make(target, debug=True)
            else:
                logger.error("编译失败，请检查错误信息")
                raise subprocess.CalledProcessError(result.returncode, result.args, result.stdout, result.stderr)
class OpenWrt(OpenWrtBase):
    def __init__(self, path: str, tag_branch: str | None = None) -> None:
        super().__init__(path)
        if os.path.isdir(os.path.join(path, ".git")):
            self.repo = pygit2.Repository(self.path)
            if tag_branch:
                self.set_tag_or_branch(tag_branch)
        else:
            self.repo = None

    def set_tag_or_branch(self, tag_branch: str) -> None:
        if not self.repo:
            msg = "没有找到git仓库"
            raise ValueError(msg)
        if tag_branch in self.repo.branches:
            # 分支
            self.repo.checkout(tag_branch)
        else:
            # 标签
            tag_ref = self.repo.lookup_reference(f"refs/tags/{tag_branch}")
            treeish = self.repo.get(tag_ref.target)
            if treeish:
                self.repo.checkout_tree(treeish)
                self.repo.head.set_target(tag_ref.target)
            else:
                msg = f"标签{tag_branch}不存在"
                raise ValueError(msg)

        self.tag_branch = tag_branch

    def feed_update(self) -> None:
        result = subprocess.run([os.path.join(self.path, "scripts", "feeds"), 'update', '-a'], cwd=self.path, capture_output=True, text=True)
        if result.returncode != 0:
            logger.error("运行命令：scripts/feeds update -a失败\nstdout: %s\nstderr: %s", result.stdout, result.stderr)
            raise subprocess.CalledProcessError(result.returncode, result.args, result.stdout, result.stderr)
        logger.debug("运行命令：scripts/feeds update -a成功\nstdout: %s\nstderr: %s", result.stdout, result.stderr)

    def feed_install(self) -> None:
        result = subprocess.run([os.path.join(self.path, "scripts", "feeds"), 'install', '-a'], cwd=self.path, capture_output=True, text=True)
        if result.returncode != 0:
            logger.error("运行命令：scripts/feeds install -a失败\nstdout: %s\nstderr: %s", result.stdout, result.stderr)
            raise subprocess.CalledProcessError(result.returncode, result.args, result.stdout, result.stderr)
        logger.debug("运行命令：scripts/feeds install -a成功\nstdout: %s\nstderr: %s", result.stdout, result.stderr)

    def make_defconfig(self) -> None:
        result = subprocess.run(['make', 'defconfig'], cwd=self.path, capture_output=True, text=True)
        if result.returncode != 0:
            logger.error("运行命令：make defconfig失败\nstdout: %s\nstderr: %s", result.stdout, result.stderr)
            raise subprocess.CalledProcessError(result.returncode, result.args, result.stdout, result.stderr)
        logger.debug("运行命令：make defconfig成功\nstdout: %s\nstderr: %s", result.stdout, result.stderr)

    def make_download(self, debug: bool = False, taget: str = "download") -> None:
        args = ['make', taget]
        if debug:
            args.extend(["-j1", "V=s"])
        else:
            args.append("-j16")
        logger.debug("运行命令：%s", " ".join(args))
        subprocess.run(args, cwd=self.path, check=True)

    def download_source(self, taget: str = "download") -> None:
        for i in range(2):
            try:
                self.make_download(debug=bool(i != 0), taget=taget)
                break
            except Exception as e:
                logger.error(f"下载源码失败: {e}")
                if i < 1:
                    logger.info("尝试重新下载源码...")

    def get_diff_config(self) -> str:
        return subprocess.run([os.path.join(self.path, "scripts", "diffconfig.sh")], cwd=self.path, capture_output=True, text=True).stdout

    def get_kernel_version(self) -> str | None:
        kernel_version = None
        if os.path.isfile(os.path.join(self.path, '.config')):
            with open(os.path.join(self.path, '.config')) as f:
                for line in f:
                    if line.startswith('CONFIG_LINUX_'):
                        match = re.match(r'^CONFIG_LINUX_(?P<major>[0-9]+)_(?P<minor>[0-9]+)=y$', line)
                        if match:
                            kernel_version = f"{match.group("major")}.{match.group("minor")}"
                            break
        logger.debug("配置%s的内核版本为%s", self.path, kernel_version)
        return kernel_version

    def get_package_config(self, package: str) -> Literal["y", "n", "m"] | None:
        package_config = None
        if os.path.isfile(os.path.join(self.path, '.config')):
            with open(os.path.join(self.path, '.config')) as f:
                for line in f:
                    if line.startswith(f'CONFIG_PACKAGE_{package}='):
                        match = re.match(fr'^CONFIG_PACKAGE_{package}=(?P<config>[ymn])$', line)
                        if match:
                            package_config = match.group("config")
                            if  package_config in ("y", "n", "m"):
                                break
                            package_config = None
        else:
            logger.warning("仓库%s的配置文件不存在", self.path)
        logger.debug("仓库%s的软件包%s的配置为%s", self.path, package, package_config)
        return package_config # type: ignore[]

    def check_package_dependencies(self) -> bool:
        subprocess.run(['gmake', '-s', 'prepare-tmpinfo'], cwd=self.path)
        if err := subprocess.run(['./scripts/package-metadata.pl', 'mk', 'tmp/.packageinfo'], cwd=self.path, capture_output=True, text=True).stderr:
            core.error(f'检查到软件包依赖问题,这有可能会导致编译错误:\n{err}')
            return False
        return True

    def fix_problems(self) -> None:
        if self.tag_branch not in ("main", "master"):
            #https://github.com/openwrt/openwrt/commit/ecc53240945c95bc77663b79ccae6e2bd046c9c8
            patch = request_get("https://github.com/openwrt/openwrt/commit/ecc53240945c95bc77663b79ccae6e2bd046c9c8.patch")
            if patch:
                if not apply_patch(patch, self.path):
                    core.error("修复内核模块依赖失败, 这可能会导致编译错误。\nhttps://github.com/openwrt/openwrt/commit/ecc53240945c95bc77663b79ccae6e2bd046c9c8")
            else:
                core.error("获取内核模块依赖修复补丁失败, 这可能会导致编译错误。\nhttps://github.com/openwrt/openwrt/commit/ecc53240945c95bc77663b79ccae6e2bd046c9c8")

        # 替换dnsmasq为dnsmasq-full
        logger.info("替换dnsmasq为dnsmasq-full")
        with open(os.path.join(self.path, 'include', 'target.mk'), encoding='utf-8') as f:
            content = f.read().replace(r"	dnsmasq ", r"	dnsmasq-full ")
        with open(os.path.join(self.path, 'include', 'target.mk'), 'w', encoding='utf-8') as f:
            f.write(content)
        # 修复broadcom.mk中的路径错误
        logger.info("修复broadcom.mk中的路径错误")
        with open(os.path.join(self.path, 'package', "kernel", "mac80211", "broadcom.mk"), encoding='utf-8') as f:
            content =  f.read().replace(r'	b43-fwsquash.py', r'	$(TOPDIR)/tools/b43-tools/files/b43-fwsquash.py')
        with open(os.path.join(self.path, 'package', "kernel", "mac80211", "broadcom.mk"), 'w', encoding='utf-8') as f:
            f.write(content)

        if self.tag_branch == "v23.05.2":
            logger.info("修复iperf3冲突")
            patch = request_get("https://github.com/openwrt/packages/commit/cea45c75c0153a190ee41dedaf6526ae08e33928.patch")
            if patch:
                if not apply_patch(patch, os.path.join(self.path, "feeds", "packages")):
                    core.error("修复iperf3冲突失败, 这可能会导致编译错误。\nhttps://github.com/openwrt/packages/commit/cea45c75c0153a190ee41dedaf6526ae08e33928")
            else:
                core.error("获取iperf3冲突修复补丁失败, 这可能会导致编译错误。\nhttps://github.com/openwrt/packages/commit/cea45c75c0153a190ee41dedaf6526ae08e33928")

        if self.tag_branch == "v23.05.3":
            logger.info("修复libpfring")
            patch1 = request_get("https://github.com/openwrt/packages/commit/534bd518f3fff6c31656a1edcd7e10922f3e06e5.patch")
            patch2 = request_get("https://github.com/openwrt/packages/commit/c3a50a9fac8f9d8665f8b012abd85bb9e461e865.patch")
            if patch1 and patch2:
                if not (apply_patch(patch1, os.path.join(self.path, "feeds", "packages")) and
                        apply_patch(patch2, os.path.join(self.path, "feeds", "packages"))):
                    core.error("修复libpfring失败, 这可能会导致编译错误。\nttps://github.com/openwrt/packages/commit/c3a50a9fac8f9d8665f8b012abd85bb9e461e865")
            else:
                core.error("获取libpfring修复补丁失败, 这可能会导致编译错误。\nttps://github.com/openwrt/packages/commit/c3a50a9fac8f9d8665f8b012abd85bb9e461e865")

        # 修复bcm27xx-gpu-fw
        logger.info("修复bcm27xx-gpu-fw")
        with open(os.path.join(paths.openwrt_k, "patches", "bcm27xx-gpu-fw.patch"), encoding='utf-8') as f:
            if not apply_patch(f.read(), self.path):
                core.error("修复bcm27xx-gpu-fw失败, 这可能会导致生成镜像生成器错误。")

    def get_packageinfos(self) -> dict:
        path = os.path.join(self.path, "tmp", ".packageinfo")
        if not os.path.exists(path):
            self.make_defconfig()

        packages = {}

        makefile = None
        package = None
        version = None
        section = None
        category = None
        title = None
        depends = None
        type_ = None

        count = 0
        with open(path, encoding='utf-8') as f:
            for line in f:
                if line.startswith("Source-Makefile: "):
                    makefile = line.split("Source-Makefile: ")[1].strip()
                if line.startswith("Package: "):
                    if count != 0:
                        packages[package] = {
                            "makefile": makefile,
                            "version": version,
                            "section": section,
                            "category": category,
                            "title": title,
                            "depends": depends,
                            "type": type_,
                        }
                    package = line.split("Package: ")[1].strip()
                    version = None
                    section = None
                    category = None
                    title = None
                    depends = None
                    type_ = None
                    count += 1
                elif line.startswith("Version: "):
                    version = line.split("Version: ")[1].strip()
                elif line.startswith("Section: "):
                    section = line.split("Section: ")[1].strip()
                elif line.startswith("Category: "):
                    category = line.split("Category: ")[1].strip()
                elif line.startswith("Title: "):
                    title = line.split("Title: ")[1].strip()
                elif line.startswith("Depends: "):
                    depends = line.split("Depends: ")[1].strip()
                elif line.startswith("Type: "):
                    type_ = line.split("Type: ")[1].strip()

            if package and package not in packages:
                packages[package] = {
                    "makefile": makefile,
                    "version": version,
                    "section": section,
                    "category": category,
                    "title": title,
                    "depends": depends,
                    "type": type_,
                }

        if count == 0:
            msg = "没有获取到任何包信息"
            raise ValueError(msg)
        logger.debug("解析出%s个包信息", count)
        return packages

    def archive(self, path: str) -> None:
        if os.path.exists(os.path.join(self.path, ".git")):
            shutil.rmtree(os.path.join(self.path, ".git"))
        if os.path.exists(os.path.join(self.path, "tmp")):
            shutil.rmtree(os.path.join(self.path, "tmp"))
        if os.path.exists(os.path.join(self.path, "dl")):
            shutil.rmtree(os.path.join(self.path, "dl"))
        with tarfile.open(path, "w:gz") as tar:
            tar.add(self.path, arcname="openwrt")

    def get_targetinfos(self) -> dict:
        path = os.path.join(self.path, "tmp", ".targetinfo")
        if not os.path.exists(path):
            self.make_defconfig()

        targets = {}

        target = None
        board = None
        name = None
        arch = None
        arch_packages = None
        feature = None
        linux_version = None
        linux_release = None
        linux_kernel_arch = None
        default_packages = None
        target_profile = {}

        count = 0
        with open(path) as f:
            for line in f:
                if line.startswith("Target: "):
                    if count != 0:
                        targets[target] = {
                            "board": board,
                            "name": name,
                            "arch": arch,
                            "arch_packages": arch_packages,
                            "feature": feature,
                            "linux_version": linux_version,
                            "linux_release": linux_release,
                            "linux_kernel_arch": linux_kernel_arch,
                            "default_packages": default_packages,
                            "target_profile": target_profile,
                        }
                    target = line.split("Target: ")[1].strip()
                    board = None
                    name = None
                    arch = None
                    arch_packages = None
                    feature = None
                    linux_version = None
                    linux_release = None
                    linux_kernel_arch = None
                    default_packages = None
                    target_profile = {}
                    count += 1
                elif line.startswith("Target-Board: "):
                    board = line.split("Target-Board: ")[1].strip()
                elif line.startswith("Target-Name: "):
                    name = line.split("Target-Name: ")[1].strip()
                elif line.startswith("Target-Arch: "):
                    arch = line.split("Target-Arch: ")[1].strip()
                elif line.startswith("Target-Arch-Packages: "):
                    arch_packages = line.split("Target-Arch-Packages: ")[1].strip()
                elif line.startswith("Target-Feature: "):
                    feature = line.split("Target-Feature: ")[1].strip().split(" ")
                elif line.startswith("Linux-Version: "):
                    linux_version = line.split("Linux-Version: ")[1].strip()
                elif line.startswith("Linux-Release: "):
                    linux_release = line.split("Linux-Release: ")[1].strip()
                elif line.startswith("Linux-Kernel-Arch: "):
                    linux_kernel_arch = line.split("Linux-Kernel-Arch: ")[1].strip()
                elif line.startswith("Default-Packages: "):
                    default_packages = line.split("Default-Packages: ")[1].strip().split(" ")
                elif line.startswith("Target-Profile: "):
                    target_profile[line.split("Target-Profile: ")[1].strip()] = {}
                elif line.startswith("Target-Profile-Name: "):
                    target_profile[list(target_profile.keys())[-1]]["name"] = line.split("Target-Profile-Name: ")[1].strip()
                elif line.startswith("Target-Profile-Packages: "):
                    target_profile[list(target_profile.keys())[-1]]["packages"] = line.split("Target-Profile-Packages: ")[1].strip().split(" ")
                elif line.startswith("Target-Profile-SupportedDevices: "):
                    target_profile[list(target_profile.keys())[-1]]["supported_devices"] = line.split("Target-Profile-SupportedDevices: ")[1].strip().split(",")

            if target and target not in targets:
                targets[target] = {
                    "board": board,
                    "name": name,
                    "arch": arch,
                    "arch_packages": arch_packages,
                    "feature": feature,
                    "linux_version": linux_version,
                    "linux_release": linux_release,
                    "linux_kernel_arch": linux_kernel_arch,
                    "default_packages": default_packages,
                    "target_profile": target_profile,
                }
        if count == 0:
            msg = "未解析出目标架构信息"
            raise ValueError(msg)
        return targets

    def get_targetinfo(self) -> dict | None:
        targets = self.get_targetinfos()
        targetinfos = None
        with open(os.path.join(self.path, ".config")) as f:
            for line in f:
                if match := re.match(r"CONFIG_TARGET_(?P<target>[^=]+)=", line):
                    target = match.group('target').replace("_", "/")
                    targetinfos = targets.get(target, targetinfos)
                    if targetinfos and target:
                        targetinfos["target"] = target
        return targetinfos

    def enable_kmods(self, exclude_list: list[str], only_kmods: bool = False) -> None:
        packages = self.get_packageinfos()
        kmods = [package for package in packages if (packages[package]["section"] == "kernel" or packages[package]["category"] == "Kernel modules")]
        logger.debug("获取到kmods: %s", kmods)
        targetinfo = self.get_targetinfo()
        if targetinfo:
            default_packages = targetinfo["default_packages"]
            logger.debug("获取到默认包: %s", default_packages)
        else:
            default_packages = []

        for _ in range(5):
            with open(os.path.join(self.path, ".config")) as f:
             config = f.read()
            with open(os.path.join(self.path, ".config"), "w") as f:
                for line in config.splitlines():
                    if match := re.match(r"# CONFIG_PACKAGE_(?P<name>[^ ]+) is not set", line):
                        name = match.group('name')
                        if name not in exclude_list and name in kmods:
                            f.write(f"CONFIG_PACKAGE_{match.group('name')}=m\n")
                        else:
                            f.write(line + "\n")
                    elif only_kmods and (match := re.match(r"CONFIG_PACKAGE_(?P<name>[^=]+)=[ym]", line)):
                        name = match.group('name')
                        package = packages.get(name)
                        if package and (package["section"] not in ("kernel", "base", "boot", "firmware", "sys", "system") and
                                        package["category"] not in ("Boot Loaders", "Firmware", "Base system", "Kernel modules", "System") and
                                        package not in default_packages):
                            logger.debug("取消编译包: %s", name)
                            continue
                        f.write(line + "\n")
                    else:
                        f.write(line + "\n")
                self.make_defconfig()
        logger.debug("启用所有kmod, 配置差异: %s", self.get_diff_config())

    def __getstate__(self) -> dict:
        state = self.__dict__.copy()
        del state['repo']
        return state

    def __setstate__(self, state: dict) -> None:
        self.__dict__.update(state)
        if os.path.isdir(os.path.join(self.path, ".git")):
            self.repo = pygit2.Repository(self.path)
        else:
            self.repo = None


class ImageBuilder(OpenWrtBase):
    def __init__(self, path: str) -> None:
        super().__init__(path)
        self.packages_path = os.path.join(path, "packages")

    def make_info(self) -> None:
        subprocess.run(["make", "info"], cwd=self.path, check=True)

    def make_manifest(self) -> None:
        subprocess.run(["make", "manifest", f'PACKAGES="{" ".join(self.get_packages())}"'], cwd=self.path, check=True)

    def make_image(self) -> None:
        subprocess.run(["make", "image", f'PACKAGES="{" ".join(self.get_packages())}"', f'FILES="{os.path.join(self.path, "files")}"'], cwd=self.path, check=True)

    def get_packages(self) -> list[str]:
        packages = []
        with open(os.path.join(self.path, ".config")) as f:
            for line in f:
                if match := re.match(r"CONFIG_PACKAGE_(?P<name>.+)=y", line):
                    packages.append(match.group('name'))  # noqa: PERF401
        return packages
