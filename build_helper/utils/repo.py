# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import contextlib
import os
from datetime import datetime, timedelta, timezone

import github
import github.GitRelease
import pygit2
import requests
from actions_toolkit.github import Context, get_octokit

from .logger import logger
from .network import gh_api_request, multi_thread_download
from .paths import paths

context = Context()
user_repo = f'{context.repo.owner}/{context.repo.repo}'

token = os.getenv('GITHUB_TOKEN')
with contextlib.suppress(Exception):
    repo = get_octokit(token).rest.get_repo(user_repo)

compiler = context.repo.owner
if user_info := gh_api_request(f"https://api.github.com/users/{compiler}", token):
    compiler = user_info.get("name", compiler)

def dl_artifact(name: str, path: str) -> str:
    for artifact in repo.get_artifacts():
        if artifact.workflow_run.id == context.run_id and artifact.name == name:
            dl_url = artifact.archive_download_url
            logger.debug(f'Downloading artifact {name} from {dl_url}')
            break
    else:
        msg = f'Artifact {name} not found'
        raise ValueError(msg)
    if not token:
        msg = "没有可用的token"
        raise KeyError(msg)

    # https://github.com/orgs/community/discussions/88698
    headers = {
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
                "Authorization": f'Bearer {token}',
            }
    multi_thread_download(dl_url, os.path.join(path, name + ".zip"), headers=headers)
    return os.path.join(path, name + ".zip")

def del_cache(key_prefix: str) -> None:
    headers = {
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
                "Authorization": f'Bearer {token}',
            }
    if response := gh_api_request(f"https://api.github.com/repos/{user_repo}/actions/caches", token):
        for cache in response["actions_caches"]:
            cache: dict
            if cache['key'].startswith(key_prefix):
                logger.info(f'Deleting cache {cache["key"]}')
                requests.delete(f"https://api.github.com/repos/{user_repo}/actions/caches/{cache['id']}", headers=headers, timeout=10)
    else:
        logger.error('Failed to get caches list')

def new_release(cfg: dict, assets: list[str], body: str) -> None:
    suffix = f"({cfg["target"]}-{cfg["subtarget"]})-[{cfg["compile"]["openwrt_tag/branch"]}]-{cfg["name"]}"
    name = "v" + datetime.now(timezone(timedelta(hours=8))).strftime('%Y.%m.%d') + "-{n}" + suffix

    releases = repo.get_releases()
    releases_names = [release.tag_name for release in releases]

    i = 0
    while True:
        release_name = name.format(n=i)
        if release_name not in releases_names:
            break
        i += 1

    current_repo = pygit2.Repository(paths.openwrt_k)
    head_commit = current_repo.head.target
    if isinstance(head_commit, pygit2.Oid):
        head_commit = head_commit.raw.hex()

    logger.info("创建新发布: %s", release_name)
    release = repo.create_git_tag_and_release(release_name,
                                              f"发布新版本:{release_name}",
                                              release_name,
                                              body,
                                              head_commit,
                                              "commit",
                                              draft=True,
                                              )
    for asset in assets:
        logger.info("上传资产: %s", asset)
        release.upload_asset(asset)

    try:
        for release in releases:
            if release.tag_name.endswith(suffix) and release.tag_name != release_name:
                logger.info("删除旧版本: %s", release.tag_name)
                release.delete_release()
    except Exception:
        logger.exception("删除旧版本失败")


def match_releases(cfg: dict) -> github.GitRelease.GitRelease | None:
    suffix = f"({cfg["target"]}-{cfg["subtarget"]})-[{cfg["compile"]["openwrt_tag/branch"]}]-{cfg["name"]}"

    releases = repo.get_releases()

    matched_releases = [release for release in releases if release.tag_name.endswith(suffix)]

    if matched_releases:
        return matched_releases[0]
    return None
