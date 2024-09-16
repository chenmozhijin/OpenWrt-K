# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import os
import tarfile
import tempfile
import zipfile

from .utils.logger import logger
from .utils.paths import paths
from .utils.repo import dl_artifact


def releases(cfg: dict) -> None:
    """发布到 GitHub"""
    logger.info("下载artifact...")

    pkgs_path = os.path.join(paths.workdir, "pakages")
    os.makedirs(pkgs_path)
    tmpdir = tempfile.TemporaryDirectory()
    pkgs_archive_path = dl_artifact(f"packages-{cfg['name']}", tmpdir.name)
    with zipfile.ZipFile(pkgs_archive_path, "r") as zip_ref:
        zip_ref.extract("packages.tar.gz", tmpdir.name)
    with tarfile.open(os.path.join(tmpdir.name, "packages.tar.gz"), "r:gz") as tar:
        for membber in tar.getmembers():
            if not os.path.exists(os.path.join(pkgs_path, membber.name)):
                tar.extract(membber, pkgs_path)

    firmware_path = os.path.join(paths.workdir, "firmware")
    os.makedirs(firmware_path)
    firmware_archive_path = dl_artifact(f"firmware-{cfg['name']}", firmware_path)
    with zipfile.ZipFile(firmware_archive_path, "r") as zip_ref:
        zip_ref.extractall(firmware_path)