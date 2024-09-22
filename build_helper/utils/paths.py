# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import os

from actions_toolkit import core
import tempfile
from .error import ConfigError
class Paths:

    def __init__(self) -> None:
        root = os.getenv("GITHUB_WORKSPACE")
        if root is None:
            self.root = os.getcwd()
        else:
            self.root = root
        self.global_config = os.path.join(self.root, "config", "OpenWrt.config")

        self.main = os.path.abspath(__import__("__main__").__file__)
        self.build_helper = os.path.dirname(self.main)
        self.openwrt_k = os.path.dirname(self.build_helper)

    @property
    def configs(self) -> dict[str, str]:
        """获取配置的名称与路径"""
        configs = {}
        try:
            from .utils import parse_config
            config_names = parse_config(self.global_config, ["config"])['config']
            if not isinstance(config_names, list) or len(config_names) == 0:
                raise ConfigError("没有获取到任何配置")
            for config in config_names:
                path = os.path.join(self.root, "config", config)
                if os.path.isdir(path):
                    configs[config] = os.path.join(self.root, "config", config)
                else:
                    core.warning(f"配置 {config} 不存在")
        except Exception as e:
            raise ConfigError(f"获取配置时出错: {e.__class__.__name__}: {e!s}") from e
        return configs

    @property
    def workdir(self) -> str:
        workdir =  os.path.join(self.root, "workdir")
        if not os.path.exists(workdir):
            os.makedirs(workdir)
        elif not os.path.isdir(workdir):
            raise NotADirectoryError(f"工作区路径 {workdir} 不是一个目录")
        return workdir

    @property
    def uploads(self) -> str:
        uploads = os.path.join(self.root, "uploads")
        if not os.path.exists(uploads):
            os.makedirs(uploads)
        elif not os.path.isdir(uploads):
            raise NotADirectoryError(f"上传区路径 {uploads} 不是一个目录")
        return uploads

    @property
    def log(self) -> str:
        return os.path.join(self.uploads, "build_helper.log")

    @property
    def errorinfo(self) -> str:
        errorinfo = os.path.join(self.root, "errorinfo")
        if not os.path.exists(errorinfo):
            os.makedirs(errorinfo)
        elif not os.path.isdir(errorinfo):
            raise NotADirectoryError(f"错误信息路径 {errorinfo} 不是一个目录")
        return errorinfo
    
    def get_tmpdir(self) -> tempfile.TemporaryDirectory:
        tmpdir = os.path.join(self.root, "tmp")
        if not os.path.exists(tmpdir):
            os.makedirs(tmpdir)
        elif not os.path.isdir(tmpdir):
            raise NotADirectoryError(f"临时目录 {tmpdir} 不是一个目录")
        return tempfile.TemporaryDirectory(dir=tmpdir)


paths = Paths()
