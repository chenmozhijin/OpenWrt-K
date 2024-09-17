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

    def make_download(self, debug: bool = False) -> None:
        args = ['make', 'download']
        if debug:
            args.extend(["-j1", "V=s"])
        else:
            args.append("-j16")
        logger.debug("运行命令：%s", " ".join(args))
        subprocess.run(args, cwd=self.path, check=True)

    def download_packages_source(self) -> None:
        for i in range(2):
            try:
                self.make_download(debug=bool(i != 0))
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

            patchs = [request_get("https://github.com/openwrt/openwrt/commit/5636ffc22d784a2a4acc5e406e54f8a5858f1435.patch"),
                      request_get("https://github.com/openwrt/openwrt/commit/446178dc367661e4277260a72a89a58a69e55751.patch"),
                      request_get("https://github.com/openwrt/openwrt/commit/ca788d615fbf780b1a1665475ed304de4276f512.patch"),
                      request_get("https://github.com/openwrt/openwrt/commit/cbf8c76d0a30838961553b75ba038ecc7a29a621.patch"),
                      request_get("https://github.com/openwrt/openwrt/commit/fcdc629144983cf5e3f5509e35149096aa2701b3.patch")]

            logger.info("更新meson")
            if patchs:
                for patch in patchs:
                    if patch:
                        if not apply_patch(patch, self.path):
                            core.error("修复meson依赖失败, 这可能会导致编译错误。")
                    else:
                        core.error("获取meson依赖修复补丁失败, 这可能会导致编译错误。")
            else:
                core.error("获取meson依赖修复补丁失败, 这可能会导致编译错误。")

        # 替换dnsmasq为dnsmasq-full
        logger.info("替换dnsmasq为dnsmasq-full")
        with open(os.path.join(self.path, 'include', 'target.mk'), encoding='utf-8') as f:
            content = re.sub(r"^	dnsmasq \\", r"	dnsmasq \\", f.read())
        with open(os.path.join(self.path, 'include', 'target.mk'), 'w', encoding='utf-8') as f:
            f.write(content)
        # 修复broadcom.mk中的路径错误
        logger.info("修复broadcom.mk中的路径错误")
        with open(os.path.join(self.path, 'package', "kernel", "mac80211", "broadcom.mk"), encoding='utf-8') as f:
            content =  f.read().replace(r'	b43-fwsquash.py', r'	$(TOPDIR)/tools/b43-tools/files/b43-fwsquash.py',)
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

    def get_packageinfo(self) -> dict | None:
        path = os.path.join(self.path, "tmp", ".targetinfo")
        if not os.path.exists(path):
            return None

        packages = {}

        makefile = ""
        package = ""
        version = ""
        section = ""
        category = ""
        title = ""
        depends = ""

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
                        }
                    package = line.split("Package: ")[1].strip()
                    version = ""
                    section = ""
                    category = ""
                    title = ""
                    depends = ""
                    count += 1
                if line.startswith("Version: "):
                    version = line.split("Version: ")[1].strip()
                if line.startswith("Section: "):
                    section = line.split("Section: ")[1].strip()
                if line.startswith("Category: "):
                    category = line.split("Category: ")[1].strip()
                if line.startswith("Title: "):
                    title = line.split("Title: ")[1].strip()
                if line.startswith("Depends: "):
                    depends = line.split("Depends: ")[1].strip()

        if count == 0:
            return None
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

    def enable_kmods(self, exclude_list: list[str]) -> None:
        for _ in range(5):
            with open(os.path.join(self.path, ".config")) as f:
             config = f.read()
            with open(os.path.join(self.path, ".config"), "w") as f:
                for line in config.splitlines():
                    if match := re.match(r"# CONFIG_PACKAGE_(?P<name>kmod[^ ]+) is not set", line):
                        if match.group('name') not in exclude_list:
                            f.write(f"CONFIG_PACKAGE_{match.group('name')}=m\n")
                        else:
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
