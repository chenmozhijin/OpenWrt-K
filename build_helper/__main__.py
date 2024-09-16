# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import gzip
from argparse import ArgumentParser

from actions_toolkit import core

from .utils.logger import logger
from .utils.upload import uploader
from .utils.utils import setup_env


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("--task", "-t", help="要执行的任务")
    parser.add_argument("--config", "-c", help="配置")
    parser.add_argument("--cache-hit", "-h", help="缓存命中")
    args = parser.parse_args()
    if args.config:
        import json
        config = json.loads(gzip.decompress(bytes.fromhex(args.config)).decode("utf-8"))
    if args.cache_hit:
        cache_hit = args.cache_hit == "true"
        logger.info("缓存命中: %s", cache_hit)
    match args.task:
        case "prepare":
            from .prepare import get_matrix, parse_configs, prepare
            setup_env()
            try:
                configs = parse_configs()
                if not configs:
                    core.set_failed("未找到任何可用的配置")
            except Exception as e:
                logger.exception("解析配置时出错")
                core.set_failed(f"解析配置时出错: {e.__class__.__name__}: {e!s}")
            try:
                prepare(configs)
                core.set_output("matrix", get_matrix(configs))
            except Exception as e:
                logger.exception("准备时出错")
                core.set_failed(f"准备时出错: {e.__class__.__name__}: {e!s}")
        case "build-prepare":
            from .build import prepare
            prepare(config)
            setup_env(build=True)
        case "base-builds":
            from .build import base_builds
            base_builds(config, cache_hit)
        case "build_packages":
            from .build import build_packages
            build_packages(config)
        case "build_image_builder":
            from .build import build_image_builder
            build_image_builder(config)
        case "build_images":
            from .build import build_images
            build_images(config)
        case "releases":
            from .releases import releases
            releases(config)

    uploader.save()

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logger.exception("发生错误")
        import os
        for root, _, files in os.walk("."):
            for file in files:
                print(f"{root}/{file}")  # noqa: T201
        core.set_failed(f"发生错误: {e.__class__.__name__}: {e!s}")
