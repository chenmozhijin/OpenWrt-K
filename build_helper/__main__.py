# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
from argparse import ArgumentParser

from actions_toolkit import core

from .utils.logger import logger
from .utils.upload import uploader
from .utils.utils import setup_env

if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("--task", "-t", help="要执行的任务")
    parser.add_argument("--config", "-c", help="配置")
    args = parser.parse_args()
    if args.config:
        import json
        config = json.loads(args.config)
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
            setup_env(build=True)
            prepare(config)
        case "base-builds":
            from .build import base_builds
            base_builds(config)

    uploader.save()
