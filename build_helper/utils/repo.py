# SPDX-FileCopyrightText: Copyright (c) 2024 沉默の金 <cmzj@cmzj.org>
# SPDX-License-Identifier: MIT
import os
from datetime import datetime, timedelta, timezone

import requests
import github
import github.GitRelease
import pygit2
from actions_toolkit.github import Context, get_octokit

from .logger import logger
from .network import dl2, gh_api_request, wait_dl_tasks
from .paths import paths

context = Context()
user_repo = f'{context.repo.owner}/{context.repo.repo}'

token = os.getenv('GITHUB_TOKEN')
try:
    repo = get_octokit(token).rest.get_repo(user_repo)
except Exception:
    pass

compiler = context.repo.owner
if user_info := gh_api_request(f"https://api.github.com/users/{compiler}"):
    compiler = user_info.get("name", compiler)

def dl_artifact(name: str, path: str) -> str:
    for artifact in repo.get_artifacts():
        if artifact.workflow_run.id == context.run_id and artifact.name == name:
            dl_url = artifact.archive_download_url
            logger.info(f'Downloading artifact {name} from {dl_url}')
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
    response = requests.get(dl_url, allow_redirects=True, headers=headers)
    if 300 <= response.status_code < 400:
        redirect_url = response.headers['Location']
    else:
        raise ValueError(f'无法获取重定向URL: {response.status_code} {response.text}')
    logger.debug(f'Redirected to {redirect_url}, response_headers: {response.headers}, cookies: {response.cookies}, content: {response.content}')
    dl = dl2(redirect_url, path, headers={"Authorization": f'Bearer {token}'})
    wait_dl_tasks([dl])
    return dl.get_dest()

def del_cache(key_prefix: str) -> None:
    if response := gh_api_request(f"https://api.github.com/repos/{user_repo}/actions/caches", token):
        for cache in response["actions_caches"]:
            cache: dict
            if cache['key'].startswith(key_prefix):
                logger.info(f'Deleting cache {cache["key"]}')
                gh_api_request(f"https://api.github.com/repos/{user_repo}/actions/caches/{cache['id']}", token)
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

    current_repo = pygit2.Repository(paths.root)
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
    except Exception as e:
        logger.exception("删除旧版本失败")
                

def match_releases(cfg: dict) -> github.GitRelease.GitRelease | None:
    suffix = f"({cfg["target"]}-{cfg["subtarget"]})-[{cfg["compile"]["openwrt_tag/branch"]}]-{cfg["name"]}"

    releases = repo.get_releases()

    matched_releases = [release for release in releases if release.tag_name.endswith(suffix)]

    if matched_releases:
        return matched_releases[0]
    return None
