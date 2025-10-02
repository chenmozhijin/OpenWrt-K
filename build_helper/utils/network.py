# SPDX-FileCopyrightText: Copyright (c) 2024-2025 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import json

import httpx

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
            response = httpx.get(url, timeout=10, follow_redirects=True, headers=headers)
            response.raise_for_status()
            return response.text  # noqa: TRY300
        except Exception as e:
            logger.warning(f"请求{url}失败， 重试次数：{i + 1}")
            error = e
    logger.error("请求失败，重试次数已用完 %s", f"{error.__class__.__name__}: {error!s}")
    return None

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
