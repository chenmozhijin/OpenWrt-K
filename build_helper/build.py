# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import os
import tarfile
import tempfile
import zipfile

from actions_toolkit import core
from actions_toolkit.github import Context

from .utils.logger import logger
from .utils.openwrt import OpenWrt
from .utils.paths import paths
from .utils.repo import dl_artifact
from .utils.upload import uploader
from .utils.utils import hash_dirs


def prepare(cfg: dict) -> None:
    context = Context()
    os.makedirs(os.path.join(paths.root, "workdir"))
    tmpdir = tempfile.TemporaryDirectory()

    logger.info("还原openwrt源码...")
    path = dl_artifact(f"openwrt-source-{cfg["name"]}", tmpdir.name)
    with zipfile.ZipFile(path, "r") as zip_ref:
        zip_ref.extract("openwrt-source.tar.gz", tmpdir.name)
    with tarfile.open(os.path.join(tmpdir.name, "openwrt-source.tar.gz"), "r") as tar_ref:
        tar_ref.extractall(os.path.join(paths.root, "workdir"))  # noqa: S202
    opemwrt = OpenWrt(os.path.join(paths.root, "workdir", "openwrt"))

    if context.job.startswith("base-builds-"):
        job_prefix = "base-builds"
        logger.info("构建toolchain缓存key...")
        toolchain_key = f"toolchain-{hash_dirs((os.path.join(opemwrt.path, "tools"), os.path.join(opemwrt.path, "toolchain")))}"
        target, subtarget = opemwrt.get_target()
        if target:
            toolchain_key += f"-{target}"
        if subtarget:
            toolchain_key += f"-{subtarget}"
        core.set_output("toolchain-key", toolchain_key)
    else:
        msg = f"未知的工作流 {context.job}"
        raise ValueError(msg)

    cache_restore_key = f"{job_prefix}-{cfg["compile"]["openwrt_tag/branch"]}"
    if target:
        cache_restore_key += f"-{target}"
    if subtarget:
        cache_restore_key += f"-{subtarget}"
    core.set_output("cache-key", f"{cache_restore_key}-{context.run_id}")
    core.set_output("cache-restore-key", cache_restore_key)
    core.set_output("use-cache", cfg["compile"]["use_cache"])
    core.set_output("openwrt-path", opemwrt.path)

def base_builds(cfg: dict) -> None:
    openwrt = OpenWrt(os.path.join(paths.root, "workdir", "openwrt"))

    logger.info("修改配置(设置编译所有kmod)...")
    openwrt.enable_kmods()

    logger.info("下载源码...")
    openwrt.download_packages_source()
    if not any(directory.startswith("toolchain-") for directory in os.listdir(os.path.join(openwrt.path, "staging_dir"))):
        logger.info("开始编译tools...")
        openwrt.make("tools/install")
        logger.info("开始编译toolchain...")
        openwrt.make("toolchain/install")

    logger.info("开始编译内核...")
    openwrt.make("target/compile")

    logger.info("归档文件...")
    tar_path = os.path.join(paths.uploads, "builds.tar.gz")
    with tarfile.open(tar_path, "w:gz") as tar:
        tar.add(os.path.join(openwrt.path, "staging_dir"), arcname="staging_dir")
    uploader.add(f"base-builds-{cfg["name"]}", tar_path, retention_days=1, compression_level=0)
