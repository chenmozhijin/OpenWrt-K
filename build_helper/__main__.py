# SPDX-FileCopyrightText: Copyright (c) 2024-2025 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import gzip
from argparse import ArgumentParser

from actions_toolkit import core

from .utils.error import ConfigParseError, PrePareError
from .utils.logger import debug, logger
from .utils.upload import uploader
from .utils.utils import setup_env

parser = ArgumentParser()
parser.add_argument("--task", "-t", help="要执行的任务")
parser.add_argument("--config", "-c", help="配置")

args = parser.parse_args()
if args.config:
    import json
    config = json.loads(gzip.decompress(bytes.fromhex(args.config)).decode("utf-8"))
else:
    config = {}


def main() -> None:
    match args.task:
        case "prepare":
            from .prepare import get_matrix, parse_configs, prepare
            setup_env()
            try:
                configs = parse_configs()
            except Exception as e:
                msg = f"解析配置时出错: {e.__class__.__name__}: {e!s}"
                raise ConfigParseError(msg) from e
            try:
                prepare(configs)
                core.set_output("matrix", get_matrix(configs))
            except Exception as e:
                msg = f"准备时出错: {e.__class__.__name__}: {e!s}"
                raise PrePareError(msg) from e
        case "build-prepare":
            from .build import prepare
            prepare(config)
        case "base-builds":
            from .build import base_builds
            base_builds(config)
        case "build_packages":
            from .build import build_packages
            build_packages(config)
        case "build_image_builder":
            from .build import build_image_builder
            build_image_builder(config)
        case "build_images_releases":
            from .build import build_images
            build_images(config)
            from .releases import releases
            releases(config)

    uploader.save()

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logger.exception("发生错误")
        logger.info("开始收集错误信息...")
        import os
        import time

        from actions_toolkit.github import Context

        from .utils.paths import paths
        errorinfo_path = paths.errorinfo
        openwrt_path = os.path.join(paths.workdir, "openwrt")
        if os.path.exists(openwrt_path):
            import shutil
            if os.path.exists(os.path.join(openwrt_path, ".config")):
                shutil.copy2(os.path.join(openwrt_path, ".config"), os.path.join(errorinfo_path, "openwrt.config"))
            if os.path.exists(os.path.join(openwrt_path, "logs")):
                shutil.copytree(os.path.join(openwrt_path, "logs"), os.path.join(errorinfo_path, "openwrt-logs"))
            if debug:
                import tarfile
                tmp_dir = paths.get_tmpdir()
                logger.info("正在打包 openwrt 文件夹...")
                with tarfile.open(os.path.join(tmp_dir.name, "openwrt.tar.gz"), "w:gz") as tar:
                    tar.add(openwrt_path, arcname="openwrt")
                uploader.add(f"{Context().job}-{config.get("name") if config else ''}-openwrt-{time.time()}",
                             os.path.join(tmp_dir.name, "openwrt.tar.gz"), retention_days=90, compression_level=0)

        with open(os.path.join(errorinfo_path, "files.txt"), "w") as f:
            for root, _, files in os.walk(paths.root):
                for file in files:
                    f.write(f"{root}/{file}\n")


        uploader.add(f"{Context().job}-{config.get("name") if config else ''}-errorinfo-{time.time()}", errorinfo_path, retention_days=90, compression_level=9)
        uploader.save()
        if not debug:
            core.notice("已收集部分错误信息,更详细信息请Re-run jobs并启用debug logging")
        core.set_failed(f"发生错误: {e.__class__.__name__}: {e!s}")
