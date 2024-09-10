# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import json

import requests
from pySmartDL import SmartDL

from .logger import logger


def request_get(url: str, retry: int = 6) -> str | None:
    for i in range(retry):
        try:
            response = requests.get(url, timeout=10, allow_redirects=True)
            response.raise_for_status()
            return response.text  # noqa: TRY300
        except:  # noqa: E722
            logger.warning(f"请求{url}失败， 重试次数：{i + 1}")
    logger.error("请求失败，重试次数已用完")
    return None


def dl2(url: str, path: str, retry: int = 6) -> SmartDL:
    task = SmartDL(urls=url, dest=path)
    task.attemps_limit = retry
    task.start()
    return task

def wait_dl_tasks(dl_tasks: list[SmartDL]) -> None:
    for task in dl_tasks:
        task.wait()
        while not task.isSuccessful():
            logger.warning("下载: %s 失败，重试第%s/%s次...", task.url, task.current_attemp, task.attemps_limit)
            task.retry()
            task.wait()
    dl_tasks.clear()

def get_gh_repo_last_releases(repo: str) -> dict | None:
    response = request_get(f"https://api.github.com/repos/{repo}/releases/latest")
    if isinstance(response, str):
        obj = json.loads(response)
        if isinstance(obj, dict):
            return obj
    return None
