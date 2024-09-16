# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import json

import requests
from pySmartDL import SmartDL
import urllib.error
from .logger import logger

HEADER = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36 Edg/128.0.0.0",
    "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7,en-GB;q=0.6",
    "accept-encoding": "gzip, deflate, br, zstd",
    "cache-control": "no-cache",
}


def request_get(url: str, retry: int = 6, headers: dict | None = None) -> str | None:
    for i in range(retry):
        try:
            response = requests.get(url, timeout=10, allow_redirects=True, headers=headers)
            response.raise_for_status()
            return response.text  # noqa: TRY300
        except:  # noqa: E722
            logger.warning(f"请求{url}失败， 重试次数：{i + 1}")
    logger.error("请求失败，重试次数已用完")
    return None


def dl2(url: str, path: str, retry: int = 6, headers: dict | None = None) -> SmartDL:
    logger.debug("下载 %s 到 %s, headers: %s", url, path, headers)
    task = SmartDL(urls=url, dest=path, progress_bar=False, request_args={"headers": HEADER if headers is None else headers})
    task.attemps_limit = retry
    try:
        task.start()
    except Exception:
        while not task.isSuccessful() or task.attemps_limit < task.current_attemp:
            try:
                logger.warning("下载: %s 失败，重试第%s/%s次...", task.url, task.current_attemp, task.attemps_limit)
                task.retry()
                break
            except Exception as e:
                logger.exception("下载: %s 重试失败： %s", task.url, f"{e.__class__.__name__}: {e!s}")
    return task

def wait_dl_tasks(dl_tasks: list[SmartDL]) -> None:
    for task in dl_tasks:
        task.wait()
        if task.isSuccessful():
            logger.info("下载: %s 成功", task.url)
        else:
            logger.error("下载: %s 失败", task.url)
            raise task.errors[-1]
    dl_tasks.clear()

def get_gh_repo_last_releases(repo: str, token: str | None = None) -> dict | None:
    return gh_api_request(f"https://api.github.com/repos/{repo}/releases/latest", token)

def gh_api_request(url: str, token: str | None = None) -> dict | None:
    headers = {
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
                }
    if token:
        headers["Authorization"] = f'Bearer {token}'
    response = request_get(url, headers=headers)
    if isinstance(response, str):
        obj = json.loads(response)
        if isinstance(obj, dict):
            return obj
    return None
