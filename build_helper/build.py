# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import os
import re
import shutil
import tarfile
import tempfile
import zipfile

from actions_toolkit import core
from actions_toolkit.github import Context

from .utils.logger import logger
from .utils.openwrt import ImageBuilder, OpenWrt
from .utils.paths import paths
from .utils.repo import del_cache, dl_artifact
from .utils.upload import uploader
from .utils.utils import hash_dirs


def get_cache_restore_key(openwrt: OpenWrt, cfg: dict) -> str:
    context = Context()
    if context.job.startswith("base-builds"):
        job_prefix = "base-builds"
    elif context.job.startswith("build-packages"):
        job_prefix = "build-packages"
    elif context.job.startswith("build-ImageBuilder"):
        job_prefix = "build-ImageBuilder"
    else:
        msg = "Invalid job"
        raise ValueError(msg)
    cache_restore_key = f"{job_prefix}-{cfg["compile"]["openwrt_tag/branch"]}"
    target, subtarget = openwrt.get_target()
    if target:
        cache_restore_key += f"-{target}"
    if subtarget:
        cache_restore_key += f"-{subtarget}"
    return cache_restore_key


def prepare(cfg: dict) -> None:
    context = Context()
    logger.debug("job: %s", context.job)

    tmpdir = tempfile.TemporaryDirectory()

    logger.info("还原openwrt源码...")
    path = dl_artifact(f"openwrt-source-{cfg["name"]}", tmpdir.name)
    with zipfile.ZipFile(path, "r") as zip_ref:
        zip_ref.extract("openwrt-source.tar.gz", tmpdir.name)
    with tarfile.open(os.path.join(tmpdir.name, "openwrt-source.tar.gz"), "r") as tar_ref:
        tar_ref.extractall(paths.workdir)  # noqa: S202
    openwrt = OpenWrt(os.path.join(paths.workdir, "openwrt"))

    if context.job.startswith("base-builds"):
        logger.info("构建toolchain缓存key...")
        toolchain_key = f"toolchain-{hash_dirs((os.path.join(openwrt.path, "tools"), os.path.join(openwrt.path, "toolchain")))}"
        target, subtarget = openwrt.get_target()
        if target:
            toolchain_key += f"-{target}"
        if subtarget:
            toolchain_key += f"-{subtarget}"
        core.set_output("toolchain-key", toolchain_key)

    elif context.job.startswith(("build-packages", "build-ImageBuilder")):
        if os.path.exists(os.path.join(openwrt.path, "staging_dir")):
            shutil.rmtree(os.path.join(openwrt.path, "staging_dir"))
        base_builds_path = dl_artifact(f"base-builds-{cfg['name']}", tmpdir.name)
        with tarfile.open(base_builds_path, "r:gz") as tar:
            tar.extractall(openwrt.path)  # noqa: S202

    elif context.job.startswith("build-images"):
        ib_path = dl_artifact(f"Image_Builder-{cfg["name"]}", tmpdir.name)
        with zipfile.ZipFile(ib_path, "r") as zip_ref:
            zip_ref.extract("openwrt-imagebuilder.tar.xz", tmpdir.name)
        with tarfile.open(os.path.join(tmpdir.name, "openwrt-imagebuilder.tar.xz"), "r:xz") as tar:
            tar.extractall(paths.workdir)  # noqa: S202
            shutil.move(os.path.join(paths.workdir, tar.getnames()[0]), os.path.join(paths.workdir, "ImageBuilder"))
        ib = ImageBuilder(os.path.join(paths.workdir, "ImageBuilder"))

        pkgs_path = dl_artifact(f"packages-{cfg['name']}", tmpdir.name)
        with zipfile.ZipFile(pkgs_path, "r") as zip_ref:
            zip_ref.extract("packages.tar.gz", tmpdir.name)
        with tarfile.open(os.path.join(tmpdir.name, "packages.tar.gz"), "r:gz") as tar:
            for membber in tar.getmembers():
                if not os.path.exists(os.path.join(ib.packages_path, membber.name)):
                    tar.extract(membber, ib.packages_path)

        shutil.copytree(os.path.join(openwrt.path, "files"), os.path.join(ib.path, "files"))
        if os.path.exists(os.path.join(ib.path, ".config")):
            os.remove(os.path.join(ib.path, ".config"))
        shutil.copy2(os.path.join(openwrt.path, ".config"), os.path.join(ib.path, ".config"))

    else:
        msg = f"未知的工作流 {context.job}"
        raise ValueError(msg)

    cache_restore_key = get_cache_restore_key(openwrt, cfg)
    core.set_output("cache-key", f"{cache_restore_key}-{context.run_id}")
    core.set_output("cache-restore-key", cache_restore_key)
    core.set_output("use-cache", cfg["compile"]["use_cache"])
    core.set_output("openwrt-path", openwrt.path)

def base_builds(cfg: dict) -> None:
    openwrt = OpenWrt(os.path.join(paths.workdir, "openwrt"))

    logger.info("修改配置(设置编译所有kmod)...")
    openwrt.enable_kmods(cfg["compile"]["kmod_compile_exclude_list"])

    logger.info("下载编译所需源码...")
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

    logger.info("删除旧缓存...")
    del_cache(get_cache_restore_key(openwrt, cfg))


def build_packages(cfg: dict) -> None:
    openwrt = OpenWrt(os.path.join(paths.workdir, "openwrt"))

    logger.info("下载编译所需源码...")
    openwrt.download_packages_source()

    logger.info("开始编译软件包...")
    openwrt.make("package/compile")

    logger.info("开始生成软件包...")
    openwrt.make("package/install")

    logger.info("打包软件包...")
    tar_path = os.path.join(paths.uploads, "packages.tar.gz")
    with tarfile.open(tar_path, "w:gz") as tar:
        for root, _dirs, files in os.walk(os.path.join(openwrt.path, "bin")):
            for file in files:
                if file.endswith(".ipk"):
                    tar.add(os.path.join(root, file), arcname=os.path.join(file))
    uploader.add(f"packages-{cfg['name']}", tar_path, retention_days=1, compression_level=0)

    logger.info("删除旧缓存...")
    del_cache(get_cache_restore_key(openwrt, cfg))

def build_image_builder(cfg: dict) -> None:
    openwrt = OpenWrt(os.path.join(paths.workdir, "openwrt"))

    logger.info("修改配置(设置编译所有kmod/取消生成镜像)...")
    openwrt.enable_kmods(cfg["compile"]["kmod_compile_exclude_list"])
    with open(os.path.join(openwrt.path, ".config")) as f:
        config = f.read()
    with open(os.path.join(openwrt.path, ".config"), "w") as f:
        for line in config.splitlines():
            if match := re.match(r"CONFIG_(?P<name>.+)_IMAGES=y", line):
                f.write(f"CONFIG_{match.group('name')}_IMAGE=n\n")
            else:
                match line:
                    case "CONFIG_TARGET_ROOTFS_TARGZ=y":
                        f.write("CONFIG_TARGET_ROOTFS_TARGZ=n\n")
                    case "CONFIG_TARGET_ROOTFS_CPIOGZ=y":
                        f.write("CONFIG_TARGET_ROOTFS_CPIOGZ=n\n")
                    case _:
                        f.write(line + "\n")
    openwrt.make_defconfig()

    logger.info("下载编译所需源码...")
    openwrt.download_packages_source()

    logger.info("开始编译软件包...")
    openwrt.make("package/compile")

    logger.info("开始生成软件包...")
    openwrt.make("package/install")

    logger.info("制作Image Builder包...")
    openwrt.make("target/install")

    logger.info("制作包索引、镜像概述信息并计算校验和...")
    openwrt.make("package/index")
    openwrt.make("json_overview_image_info")
    openwrt.make("checksum")

    logger.info("打包kmods...")
    tar_path = os.path.join(paths.uploads, "kmods.tar.gz")
    with tarfile.open(tar_path, "w:gz") as tar:
        for root, _dirs, files in os.walk(os.path.join(openwrt.path, "bin")):
            for file in files:
                if file.startswith("kmod-") and file.endswith(".ipk"):
                    tar.add(os.path.join(root, file), arcname=file)
    uploader.add(f"kmods-{cfg['name']}", tar_path, retention_days=1, compression_level=0)

    target, subtarget = openwrt.get_target()
    if target is None or subtarget is None:
        msg = "无法获取target信息"
        raise RuntimeError(msg)
    bl_path = os.path.join(openwrt.path, "bin", "targets", target, subtarget, f"openwrt-imagebuilder-{target}-{subtarget}.Linux-x86_64.tar.xz")
    shutil.move(bl_path, os.path.join(paths.uploads, "openwrt-imagebuilder.tar.xz"))
    bl_path = os.path.join(paths.uploads, "openwrt-imagebuilder.tar.xz")
    uploader.add(f"Image_Builder-{cfg['name']}", bl_path, retention_days=1, compression_level=0)

    logger.info("删除旧缓存...")
    del_cache(get_cache_restore_key(openwrt, cfg))

def build_images(cfg: dict) -> None:
    ib = ImageBuilder(os.path.join(paths.workdir, "ImageBuilder"))

    logger.info("收集镜像信息...")
    ib.make_info()
    ib.make_manifest()

    logger.info("开始构建镜像...")
    ib.make_image()

    target, subtarget = ib.get_target()
    if target is None or subtarget is None:
        msg = "无法获取target信息"
        raise RuntimeError(msg)

    logger.info("准备上传...")
    uploader.add(f"firmware-{cfg['name']}", os.path.join(ib.path, "bin", "targets", target, subtarget, "*"), retention_days=1, compression_level=0)
