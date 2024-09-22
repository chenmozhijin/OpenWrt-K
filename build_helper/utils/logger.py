# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import io
import logging
import os
import sys

from actions_toolkit import core

from .paths import paths

logger = logging.getLogger("build_helper")

formatter = logging.Formatter('[%(levelname)s]%(asctime)s- %(module)s(%(lineno)d) - %(funcName)s:%(message)s')

# 标准输出
handler = logging.StreamHandler(sys.stdout)
if isinstance(sys.stdout, io.TextIOWrapper):
    sys.stdout.reconfigure(encoding='utf-8')
handler.setFormatter(formatter)

# 日志等级
if core.is_debug() or os.getenv("BUILD_HELPER_DEBUG") == "1" or os.getenv("BUILD_HELPER_DEBUG", "").lower() == "true":
    handler.setLevel(logging.DEBUG)
    logger.setLevel(logging.DEBUG)
    debug = True
else:
    handler.setLevel(logging.INFO)
    logger.setLevel(logging.INFO)
    debug = False
logger.addHandler(handler)
# 文件
handler = logging.FileHandler(filename=paths.log, encoding="utf-8")
handler.setFormatter(formatter)
handler.setLevel(logging.DEBUG)
logger.addHandler(handler)



