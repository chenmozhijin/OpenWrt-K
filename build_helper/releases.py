# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import json
import os
import shutil
from datetime import datetime, timedelta, timezone

from .utils.logger import logger
from .utils.network import request_get
from .utils.openwrt import ImageBuilder
from .utils.paths import paths
from .utils.repo import dl_artifact, match_releases, new_release


def releases(cfg: dict) -> None:
    """发布到 GitHub"""
    logger.info("下载artifact...")


    tmpdir = paths.get_tmpdir()
    pkgs_archive_path = dl_artifact(f"packages-{cfg['name']}", tmpdir.name)
    shutil.move(pkgs_archive_path, os.path.join(paths.uploads, "packages.zip"))
    pkgs_archive_path = os.path.join(paths.uploads, "packages.zip")
    kmods_archive_path = dl_artifact(f"kmods-{cfg['name']}", tmpdir.name)
    shutil.move(kmods_archive_path, os.path.join(paths.uploads, "kmods.zip"))
    kmods_archive_path = os.path.join(paths.uploads, "kmods.zip")

    tmpdir.cleanup()

    ib = ImageBuilder(os.path.join(paths.workdir, "ImageBuilder"))
    target, subtarget = ib.get_target()
    if target is None or subtarget is None:
        msg = "无法获取target信息"
        raise RuntimeError(msg)
    firmware_path = str(shutil.copytree(os.path.join(ib.path, "bin", "targets", target, subtarget), os.path.join(paths.uploads, "firmware")))

    current_manifest = None
    profiles = None
    for root, _, files in os.walk(firmware_path):
        for file in files:
            if file.endswith(".manifest"):
                with open(os.path.join(root, file)) as f:
                    current_manifest = f.read()
            elif file == "profiles.json":
                with open(os.path.join(root, file)) as f:
                    try:
                        profiles = json.load(f)
                        if not isinstance(profiles, dict):
                            logger.error("profiles.json格式错误")
                            profiles = None
                    except json.JSONDecodeError:
                        logger.exception("解析profiles.json失败")
                        continue

    assets = []
    for root, _, files in os.walk(paths.uploads):
        for file in files:
            assets.append(os.path.join(root, file))  # noqa: PERF401

    current_packages = {line.split(" - ")[0]: line.split(" - ")[1] for line in current_manifest.splitlines()} if current_manifest else None

    try:
        changelog = ""
        if release := match_releases(cfg):
            old_manifest = None
            for asset in release.get_assets():
                if asset.name.endswith(".manifest"):
                    old_manifest = request_get(asset.browser_download_url)

            if old_manifest and current_packages:
                old_packages = {line.split(" - ")[0]: line.split(" - ")[1] for line in old_manifest.splitlines()}

                for pkg, version in current_packages.items():
                    if pkg in old_packages:
                        if old_packages[pkg] != version and not pkg.startswith("luci-i18n-"):
                            changelog += f"更新: {pkg} {old_packages[pkg]} -> {version}\n"
                    else:
                        changelog += f"新增: {pkg} {version}\n"
                for pkg, version in old_packages.items():
                    if pkg not in current_packages:
                        changelog += f"移除: {pkg} {version}\n"

            changelog = "更新日志:\n" + changelog if changelog else "无任何软件包更新"

        body = f"编译完成于: {datetime.now(timezone(timedelta(hours=8))).strftime('%Y-%m-%d %H:%M:%S')}\n"
        body += f"使用的配置: {cfg['name']}\n"
        if profiles:
            if (version_number := profiles.get("version_number")) and (version_code := profiles.get('version_code')):
                body += f"OpenWrt版本: {version_number} {version_code}\n"
            if target := profiles.get("target"):
                body += f"目标平台: {target}\n"
        if current_packages and (kernel_ver := current_packages.get("kernel")):
            body += f"内核版本: {kernel_ver}\n"

        if changelog:
            body += f"\n\n{changelog}"

        new_release(cfg, assets, body)

    except Exception:
        logger.exception("获取旧版本信息并对照失败")
