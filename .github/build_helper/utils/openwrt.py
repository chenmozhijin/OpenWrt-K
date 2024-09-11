# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import os
import re
import subprocess
from typing import Literal

import pygit2
from actions_toolkit import core

from .utils import apply_patch
from .logger import logger
from .network import request_get


class OpenWrt:
    def __init__(self, path: str, tag_branch: str) -> None:
        self.path = path
        self.repo = pygit2.Repository(self.path)
        self.set_tag_or_branch(tag_branch)

    def set_tag_or_branch(self, tag_branch: str) -> None:
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
                raise ValueError(f"标签{tag_branch}不存在")

        self.tag_branch = tag_branch

    def feed_update(self) -> None:
        subprocess.run([os.path.join(self.path, "scripts", "feeds"), 'update', '-a'], cwd=self.path)

    def feed_install(self) -> None:
        subprocess.run([os.path.join(self.path, "scripts", "feeds"), 'install', '-a'], cwd=self.path)

    def make_defconfig(self) -> None:
        subprocess.run(['make', 'defconfig'], cwd=self.path)

    def apply_config(self, config: str) -> None:
        with open(os.path.join(self.path, '.config'), 'w') as f:
            f.write(config)

    def get_diff_config(self) -> str:
        return subprocess.run([os.path.join(self.path, "scripts", "diffconfig.sh")], cwd=self.path).stdout.decode()

    def get_kernel_version(self) -> str | None:
        kernel_version = None
        if os.path.isfile(os.path.join(self.path, '.config')):
            with open(os.path.join(self.path, '.config')) as f:
                for line in f:
                    if line.startswith('CONFIG_LINUX_'):
                        match = re.match(r'^CONFIG_LINUX_([0-9]+)_([0-9]+)=y$', line)
                        if match:
                            kernel_version = f"{match.group(0)}.{match.group(1)}"
                            break
        logger.debug("仓库%s的内核版本为%s", self.path, kernel_version)
        return kernel_version

    def get_arch(self) -> tuple[str | None, str | None]:
        arch = None
        version = None
        if os.path.isfile(os.path.join(self.path, '.config')):
            with open(os.path.join(self.path, '.config')) as f:
                for line in f:
                    if line.startswith('CONFIG_ARCH='):
                        match = re.match(r'^CONFIG_ARCH="(.*)"$', line)
                        if match:
                            arch = match.group(0)
                            break
                    elif line.startswith('CONFIG_arm_'):
                        match = re.match(r'^CONFIG_arm_([0-9]+)=y$', line)
                        if match:
                            version = match.group(0)
                            break
        return arch, version

    def get_package_config(self, package: str) -> Literal["y", "n", "m"] | None:
        package_config = None
        if os.path.isfile(os.path.join(self.path, '.config')):
            with open(os.path.join(self.path, '.config')) as f:
                for line in f:
                    if line.startswith(f'CONFIG_PACKAGE_{package}='):
                        match = re.match(r'^CONFIG_PACKAGE_{package}=([ymn])$', line)
                        if match:
                            package_config = match.group(0)
                            if  package_config in ["y", "n", "m"]:
                                break
                            package_config = None
        return package_config # type: ignore[]

    def check_package_dependencies(self) -> bool:
        subprocess.run(['gmake', '-s', 'prepare-tmpinfo'], cwd=self.path)
        if err := subprocess.run(['./scripts/package-metadata.pl', 'mk', 'tmp/.packageinfo'], cwd=self.path).stderr:
            core.error(f'检查到软件包依赖问题,这有可能会导致编译错误:\n{err.decode()}')
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
            content = re.sub(r"^	dnsmasq \\", r"	dnsmasq \\", f.read())
        with open(os.path.join(self.path, 'include', 'target.mk'), 'w', encoding='utf-8') as f:
            f.write(content)
        # 修复broadcom.mk中的路径错误
        logger.info("修复broadcom.mk中的路径错误")
        with open(os.path.join(self.path, 'package', "kernel", "mac80211", "broadcom.mk"), encoding='utf-8') as f:
            content = re.sub(r'	b43-fwsquash.py "$(CONFIG_B43_FW_SQUASH_PHYTYPES)" "$(CONFIG_B43_FW_SQUASH_COREREVS)"',
                             r'	$(TOPDIR)/tools/b43-tools/files/b43-fwsquash.py "$(CONFIG_B43_FW_SQUASH_PHYTYPES)" "$(CONFIG_B43_FW_SQUASH_COREREVS)"',
                             f.read())
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



